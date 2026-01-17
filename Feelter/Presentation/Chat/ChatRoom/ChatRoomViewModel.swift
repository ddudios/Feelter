//
//  ChatRoomViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import UIKit
import Foundation
import Combine

final class ChatRoomViewModel {

    // MARK: - Input/Output

    struct Input {
        /// 화면 진입 (viewDidLoad)
        let viewDidLoad: AnyPublisher<Void, Never>

        /// 화면 벗어남 (viewWillDisappear)
        let viewWillDisappear: AnyPublisher<Void, Never>

        /// 메시지 전송 버튼 탭
        let sendButtonTapped: AnyPublisher<Void, Never>

        /// 입력 중인 메시지 텍스트
        let messageText: AnyPublisher<String, Never>

        /// 선택된 이미지들 (전송 시)
        let selectedImages: AnyPublisher<[UIImage], Never>
    }

    struct Output {
        /// 메시지 목록
        let messages: AnyPublisher<[ChatMessage], Never>

        /// 로딩 상태
        let isLoading: AnyPublisher<Bool, Never>

        /// 전송 중 상태
        let isSending: AnyPublisher<Bool, Never>

        /// 에러 메시지
        let error: AnyPublisher<String?, Never>

        /// 스크롤 트리거 (새 메시지 추가 시)
        let scrollToBottom: AnyPublisher<Void, Never>

        /// 전송 버튼 활성화 상태
        let isSendButtonEnabled: AnyPublisher<Bool, Never>
    }

    // MARK: - Dependencies

    private let chatRoom: ChatRoom
    private let roomId: String
    private let fetchChatHistoryUsecase: FetchChatHistoryUsecase
    private let sendMessageUsecase: SendMessageUsecase
    private let repository: ChatRepositoryProtocol

    // MARK: - State

    /// 현재 메시지 목록
    private let messagesSubject = CurrentValueSubject<[ChatMessage], Never>([])

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    /// 스크롤 트리거 (재전송 시에도 사용)
    private let scrollToBottomSubject = PassthroughSubject<Void, Never>()

    /// 메시지 전송 대기열 관리자
    private let queueManager = MessageQueueManager()

    /// 네트워크 모니터
    private let networkMonitor = NetworkMonitor.shared

    // MARK: - Initialization

    init(
        chatRoom: ChatRoom,
        fetchChatHistoryUsecase: FetchChatHistoryUsecase,
        sendMessageUsecase: SendMessageUsecase,
        repository: ChatRepositoryProtocol
    ) {
        self.chatRoom = chatRoom
        self.roomId = chatRoom.roomId
        self.fetchChatHistoryUsecase = fetchChatHistoryUsecase
        self.sendMessageUsecase = sendMessageUsecase
        self.repository = repository

        // 채팅방 정보를 먼저 CoreData에 저장
        // 이렇게 해야 메시지를 저장할 때 chatRoom relationship을 설정할 수 있음
        do {
            try repository.ensureChatRoomExists(chatRoom)
        } catch {
        }

        // Repository의 실시간 업데이트 구독
        setupRealtimeUpdates()

        // 네트워크 재연결 감지 구독
        setupNetworkMonitoring()
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let isSendingSubject = CurrentValueSubject<Bool, Never>(false)
        let errorSubject = PassthroughSubject<String?, Never>()

        // 입력 텍스트 상태 저장
        let messageTextSubject = CurrentValueSubject<String, Never>("")
        input.messageText
            .assign(to: \.value, on: messageTextSubject)
            .store(in: &cancellables)

        // 선택된 이미지 상태 저장
        let selectedImagesSubject = CurrentValueSubject<[UIImage], Never>([])
        input.selectedImages
            .assign(to: \.value, on: selectedImagesSubject)
            .store(in: &cancellables)

        // 전송 버튼 활성화 상태
        let isSendButtonEnabled = messageTextSubject
            .map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .eraseToAnyPublisher()

        // viewDidLoad: 채팅 내역 로드 + Socket 연결 + 자동 재전송
        input.viewDidLoad
            .sink { [weak self] in
                guard let self = self else { return }

                // 1. 채팅 내역 로드
                self.loadChatHistory(
                    isLoadingSubject: isLoadingSubject,
                    errorSubject: errorSubject
                )

                // 2. Socket 연결
                self.repository.connectSocket(roomId: self.roomId)

                // 3. 마지막 읽은 시간 업데이트
                Task {
                    try? await self.repository.updateLastReadDate(roomId: self.roomId)
                }

                // 4. 실패한 메시지 자동 재전송 (네트워크 연결되어 있을 때만)
                if self.networkMonitor.isConnected {
                    Task {
                        await self.retryFailedMessages()
                    }
                }
            }
            .store(in: &cancellables)

        // viewWillDisappear: Socket 연결 해제
        input.viewWillDisappear
            .sink { [weak self] in
                self?.repository.disconnectSocket()
            }
            .store(in: &cancellables)

        // sendButtonTapped: 메시지 전송
        input.sendButtonTapped
            .sink { [weak self] in
                guard let self = self else { return }
                let text = messageTextSubject.value
                let images = selectedImagesSubject.value

                self.sendMessage(
                    text: text,
                    images: images,
                    isSendingSubject: isSendingSubject,
                    errorSubject: errorSubject,
                    scrollToBottomSubject: scrollToBottomSubject
                )

                // 입력창 초기화
                messageTextSubject.send("")
                selectedImagesSubject.send([])
            }
            .store(in: &cancellables)

        return Output(
            messages: messagesSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher(),
            isSending: isSendingSubject.eraseToAnyPublisher(),
            error: errorSubject.eraseToAnyPublisher(),
            scrollToBottom: scrollToBottomSubject.eraseToAnyPublisher(),
            isSendButtonEnabled: isSendButtonEnabled
        )
    }

    // MARK: - Private Methods

    /// 채팅 내역 로드
    ///
    /// 동작:
    /// 1. 로딩 시작
    /// 2. UseCase 호출
    /// 3. Subject 업데이트
    /// 4. 로딩 종료
    ///
    private func loadChatHistory(
        isLoadingSubject: CurrentValueSubject<Bool, Never>,
        errorSubject: PassthroughSubject<String?, Never>
    ) {
        isLoadingSubject.send(true)

        Task {
            do {
                let messages = try await fetchChatHistoryUsecase.execute(roomId: roomId)

                await MainActor.run {
                    messagesSubject.send(messages)
                    isLoadingSubject.send(false)
                }
            } catch {
                await MainActor.run {
                    isLoadingSubject.send(false)
                    errorSubject.send(error.localizedDescription)
                }
            }
        }
    }

    /// 메시지 전송
    ///
    /// 동작:
    /// 1. 전송 중 상태 시작
    /// 2. 텍스트만 있거나, 텍스트+이미지가 있을 때만 전송
    /// 3. 이미지만 보내는 것은 차단
    /// 4. 대기열이 비어있으면 바로 전송, 아니면 대기열에 추가
    /// 5. 성공: 스크롤
    /// 6. 실패: 에러 표시
    /// 7. 전송 중 상태 종료
    ///
    private func sendMessage(
        text: String,
        images: [UIImage],
        isSendingSubject: CurrentValueSubject<Bool, Never>,
        errorSubject: PassthroughSubject<String?, Never>,
        scrollToBottomSubject: PassthroughSubject<Void, Never>
    ) {
        isSendingSubject.send(true)

        Task {
            do {
                let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasImages = !images.isEmpty

                // 텍스트가 없으면 전송 불가 (이미지만 보내기 차단)
                guard hasText else {
                    await MainActor.run {
                        isSendingSubject.send(false)
                        errorSubject.send("텍스트를 입력해주세요")
                    }
                    return
                }

                var fileUrls: [String] = []

                // 1. 이미지가 있으면 업로드
                if hasImages {
                    // UIImage -> Data 변환
                    let imageDataArray = images.compactMap { $0.jpegData(compressionQuality: 0.8) }

                    // Repository의 uploadFiles 메서드 호출
                    fileUrls = try await repository.uploadFiles(roomId: roomId, imageData: imageDataArray)
                }

                // 2. 대기열 확인
                let isQueueEmpty = await queueManager.isEmpty()
                let isCurrentlySending = await queueManager.isCurrentlySending()

                if isQueueEmpty && !isCurrentlySending {
                    // 대기열이 비어있고 전송 중이 아니면 바로 전송
                    _ = try await sendMessageUsecase.execute(
                        roomId: roomId,
                        content: text,
                        files: fileUrls
                    )
                } else {
                    // 대기열에 추가
                    let item = MessageQueueManager.QueueItem(
                        messageId: UUID().uuidString,  // 임시 ID
                        content: text,
                        files: fileUrls,
                        isRetry: false
                    )

                    await queueManager.enqueue(item)

                    // 대기열 처리 시작
                    await processQueue()
                }

                await MainActor.run {
                    isSendingSubject.send(false)
                    scrollToBottomSubject.send()
                }
            } catch {
                await MainActor.run {
                    isSendingSubject.send(false)

                    // SendMessageError의 errorDescription 사용
                    if let sendError = error as? SendMessageUsecase.SendMessageError {
                        errorSubject.send(sendError.errorDescription)
                    } else {
                        errorSubject.send(error.localizedDescription)
                    }
                }
            }
        }
    }

    /// Repository의 실시간 업데이트 구독
    ///
    /// Repository가 observeMessages() Publisher를 제공
    /// - Socket.IO로 새 메시지 수신 시
    /// - CoreData 변경 시
    /// → 자동으로 messagesSubject 업데이트
    ///
    private func setupRealtimeUpdates() {
        repository.observeMessages(roomId: roomId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.messagesSubject.send(messages)
            }
            .store(in: &cancellables)
    }

    /// 네트워크 재연결 감지 및 자동 재전송
    ///
    /// 동작:
    /// 1. 네트워크 재연결 이벤트 구독
    /// 2. 재연결 시 실패한 메시지 조회 (24시간 이내, 최근 20개)
    /// 3. 대기열에 추가 후 순차 전송
    ///
    private func setupNetworkMonitoring() {
        networkMonitor.networkReconnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handleNetworkReconnected()
            }
            .store(in: &cancellables)
    }

    /// 네트워크 재연결 시 자동 재전송 처리
    private func handleNetworkReconnected() {
        Task {
            await retryFailedMessages()
        }
    }

    /// 실패한 메시지 자동 재전송
    ///
    /// 동작:
    /// 1. CoreData에서 실패한 메시지 조회 (24시간 이내, 최근 20개, FIFO)
    /// 2. 대기열에 추가
    /// 3. 순차 전송
    ///
    func retryFailedMessages() async {
        do {
            // 1. 실패한 메시지 조회
            let failedMessages = try await repository.fetchFailedMessages(roomId: roomId)

            guard !failedMessages.isEmpty else { return }

            // 2. 대기열에 추가
            for message in failedMessages {
                guard let content = message.content else { continue }

                let item = MessageQueueManager.QueueItem(
                    messageId: message.chatId,
                    content: content,
                    files: message.files,
                    isRetry: true
                )

                await queueManager.enqueue(item)
            }

            // 3. 대기열 처리
            await processQueue()

        } catch {
            // 조용히 실패 처리
        }
    }

    /// 대기열 처리
    private func processQueue() async {
        let successCount = await queueManager.processQueue(
            repository: repository,
            roomId: roomId,
            networkMonitor: networkMonitor
        )

        // 성공한 메시지가 있으면 스크롤
        if successCount > 0 {
            await MainActor.run {
                scrollToBottomSubject.send()
            }
        }
    }

    // MARK: - File Upload

    /// 채팅방을 읽음으로 표시
    /// - viewDidAppear: 채팅방 진입 시
    /// - appDidBecomeActive: 백그라운드에서 복귀 시
    func markChatRoomAsRead() {
        Task {
            do {
                try await repository.updateLastReadDate(roomId: roomId)
            } catch {
            }
        }
    }

    /// 파일 전송 (즉시 전송)
    ///
    /// 동작:
    /// 1. Keychain에서 최신 토큰/사용자 정보 재확인
    /// 2. Repository를 통해 파일 업로드 (multipart/form-data)
    /// 3. 업로드된 URL로 메시지 전송
    /// 4. 성공 시 UI 즉시 반영
    ///
    /// - Parameters:
    ///   - data: 파일 바이너리 데이터
    ///   - fileName: 파일명 (확장자 포함)
    ///   - mimeType: MIME 타입 (예: "application/pdf")
    ///   - completion: 완료 콜백 (성공 여부, 에러 메시지)
    func sendFile(
        data: Data,
        fileName: String,
        mimeType: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        Task {
            do {
                // 1. Keychain에서 최신 토큰 및 사용자 정보 재확인 (방어 코드)
                // - 인증 토큰이 없으면 API 호출 자체가 실패하므로 먼저 확인
                guard let accessToken = KeychainManager.shared.read(account: "accessToken"),
                      !accessToken.isEmpty else {
                    await MainActor.run {
                        completion(false, "로그인이 필요합니다. 다시 로그인해주세요.")
                    }
                    return
                }

                // userId도 재확인 (Repository에서 필요)
                guard let userId = KeychainManager.shared.read(account: "userId"),
                      !userId.isEmpty else {
                    await MainActor.run {
                        completion(false, "사용자 정보를 찾을 수 없습니다. 다시 로그인해주세요.")
                    }
                    return
                }


                // 2. Repository를 통해 파일 업로드 (인증 헤더 자동 포함)
                // NetworkManager의 AuthenticationInterceptor가 accessToken을 헤더에 추가
                let fileUrls = try await repository.uploadFiles(roomId: roomId, imageData: [data])

                guard !fileUrls.isEmpty else {
                    await MainActor.run {
                        completion(false, "파일 업로드에 실패했습니다.")
                    }
                    return
                }


                // 3. 업로드된 파일 URL로 메시지 전송 (sendMessageUsecase 사용)
                // content는 필수값이므로 파일명을 포함한 기본 텍스트 전송
                let fileContent = "\(fileName)"

                _ = try await sendMessageUsecase.execute(
                    roomId: roomId,
                    content: fileContent,
                    files: fileUrls
                )


                // 4. 성공 콜백
                await MainActor.run {
                    completion(true, nil)
                }

            } catch {

                await MainActor.run {
                    // 에러 메시지 구체화
                    let errorMessage: String
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            errorMessage = "인터넷 연결을 확인해주세요."
                        case .timedOut:
                            errorMessage = "서버 응답 시간이 초과되었습니다."
                        default:
                            errorMessage = "네트워크 오류가 발생했습니다."
                        }
                    } else if let repoError = error as? RepositoryError {
                        errorMessage = repoError.errorDescription ?? "알 수 없는 오류가 발생했습니다."
                    } else {
                        errorMessage = error.localizedDescription
                    }

                    completion(false, errorMessage)
                }
            }
        }
    }

    // MARK: - Retry Message

    /// 실패한 메시지 재전송
    ///
    /// 동작:
    /// 1. 기존 실패 메시지를 즉시 삭제 (Repository에서 처리)
    /// 2. 새 메시지로 재전송 (text + files)
    /// 3. 성공 시 새 메시지는 자동으로 가장 아래(최근)로 이동
    /// 4. 실패 시 새로운 failed 메시지 생성
    ///
    /// - Parameters:
    ///   - messageId: 실패한 메시지의 ID (삭제용)
    ///   - text: 메시지 텍스트
    ///   - files: 첨부 파일 URL 배열 (이미 업로드된 경우)
    func retryMessage(messageId: String, text: String?, files: [String]) {
        Task {
            // text가 nil이거나 빈 문자열이면 에러
            guard let content = text, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await MainActor.run {
                    // 에러 메시지 표시 (선택적)
                }
                return
            }

            // 1. 기존 실패 메시지 즉시 삭제
            do {
                try await repository.deleteMessage(chatId: messageId)
            } catch {
                // 삭제 실패해도 재전송 시도
            }

            // 2. 새 메시지 전송 (sendMessageUsecase가 sending 상태로 저장 후 전송)
            do {
                _ = try await sendMessageUsecase.execute(
                    roomId: roomId,
                    content: content,
                    files: files
                )

                // 3. 성공: 자동으로 messagesSubject가 업데이트됨 (Repository의 observeMessages)
                // 스크롤을 가장 아래로 이동
                await MainActor.run {
                    scrollToBottomSubject.send()
                }

            } catch {
                // 4. 실패: 새로운 failed 메시지가 자동으로 생성됨 (Repository의 sendMessage에서 처리)
                // 사용자는 다시 재전송 버튼을 누를 수 있음
                await MainActor.run {
                    // 조용히 실패 처리
                }
            }
        }
    }
}
