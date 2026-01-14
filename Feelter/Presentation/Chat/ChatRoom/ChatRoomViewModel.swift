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
            print("⚠️ [ViewModel] 채팅방 저장 실패: \(error)")
        }

        // Repository의 실시간 업데이트 구독
        setupRealtimeUpdates()
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let isSendingSubject = CurrentValueSubject<Bool, Never>(false)
        let errorSubject = PassthroughSubject<String?, Never>()
        let scrollToBottomSubject = PassthroughSubject<Void, Never>()

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

        // viewDidLoad: 채팅 내역 로드 + Socket 연결
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
                try? self.repository.updateLastReadDate(roomId: self.roomId)
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
    /// 4. 성공: 스크롤
    /// 5. 실패: 에러 표시
    /// 6. 전송 중 상태 종료
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

                // 1. 텍스트 메시지 전송 (이미지 포함 여부와 관계없이)
                if hasImages {
                    // UIImage -> Data 변환
                    let imageDataArray = images.compactMap { $0.jpegData(compressionQuality: 0.8) }

                    // Repository의 uploadFiles 메서드 호출
                    let fileUrls = try await repository.uploadFiles(roomId: roomId, imageData: imageDataArray)

                    // 텍스트와 이미지를 함께 전송
                    _ = try await sendMessageUsecase.execute(
                        roomId: roomId,
                        content: text,
                        files: fileUrls
                    )
                } else {
                    // 텍스트만 전송
                    _ = try await sendMessageUsecase.execute(
                        roomId: roomId,
                        content: text,
                        files: []
                    )
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
}
