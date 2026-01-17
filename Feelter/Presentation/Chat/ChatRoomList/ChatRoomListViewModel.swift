//
//  ChatRoomListViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation
import Combine


final class ChatRoomListViewModel {

    // MARK: - Input/Output

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>

        /// Pull-to-Refresh
        let refreshTrigger: AnyPublisher<Void, Never>

        /// 채팅방 선택
        let chatRoomSelected: AnyPublisher<IndexPath, Never>
    }

    struct Output {
        /// 채팅방 목록
        let chatRooms: AnyPublisher<[ChatRoom], Never>

        /// 에러 메시지
        let error: AnyPublisher<String?, Never>

        /// 선택된 채팅방 (화면 이동용)
        let selectedChatRoom: AnyPublisher<ChatRoom, Never>
    }

    // MARK: - Dependencies

    private let fetchChatRoomsUsecase: FetchChatRoomsUsecase
    private let repository: ChatRepositoryProtocol

    // MARK: - State

    /// 현재 채팅방 목록
    private let chatRoomsSubject = CurrentValueSubject<[ChatRoom], Never>([])

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        fetchChatRoomsUsecase: FetchChatRoomsUsecase,
        repository: ChatRepositoryProtocol
    ) {
        self.fetchChatRoomsUsecase = fetchChatRoomsUsecase
        self.repository = repository

        // Repository의 실시간 업데이트 구독
        setupRealtimeUpdates()
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let errorSubject = PassthroughSubject<String?, Never>()
        let selectedChatRoomSubject = PassthroughSubject<ChatRoom, Never>()

        input.viewDidLoad
            .sink { [weak self] in
                self?.loadChatRooms(
                    isLoadingSubject: isLoadingSubject,
                    errorSubject: errorSubject
                )
            }
            .store(in: &cancellables)

        // refreshTrigger: Pull-to-Refresh
        input.refreshTrigger
            .sink { [weak self] in
                self?.loadChatRooms(
                    isLoadingSubject: isLoadingSubject,
                    errorSubject: errorSubject
                )
            }
            .store(in: &cancellables)

        // chatRoomSelected: 채팅방 선택
        input.chatRoomSelected
            .compactMap { [weak self] indexPath -> ChatRoom? in
                guard let self = self else { return nil }
                let chatRooms = self.chatRoomsSubject.value
                guard indexPath.row < chatRooms.count else { return nil }
                return chatRooms[indexPath.row]
            }
            .sink { chatRoom in
                selectedChatRoomSubject.send(chatRoom)
            }
            .store(in: &cancellables)

        return Output(
            chatRooms: chatRoomsSubject.eraseToAnyPublisher(),
            error: errorSubject.eraseToAnyPublisher(),
            selectedChatRoom: selectedChatRoomSubject.eraseToAnyPublisher()
        )
    }

    // MARK: - Private Methods
    /// 채팅방 목록 로드
    ///
    /// 동작:
    /// 1. 로딩 시작
    /// 2. UseCase 호출
    /// 3. Subject 업데이트
    /// 4. 로딩 종료
    ///
    private func loadChatRooms(
        isLoadingSubject: CurrentValueSubject<Bool, Never>,
        errorSubject: PassthroughSubject<String?, Never>
    ) {
        isLoadingSubject.send(true)

        Task {
            do {
                let chatRooms = try await fetchChatRoomsUsecase.execute()

                await MainActor.run {
                    chatRoomsSubject.send(chatRooms)
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

    /// Repository의 실시간 업데이트 구독
    ///
    /// Repository가 observeChatRooms() Publisher를 제공
    /// - Socket.IO로 새 메시지 수신 시
    /// - CoreData 변경 시
    /// → 자동으로 chatRoomsSubject 업데이트
    ///
    private func setupRealtimeUpdates() {
        repository.observeChatRooms()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chatRooms in
                self?.chatRoomsSubject.send(chatRooms)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// 특정 채팅방에 실패한 메시지가 있는지 확인
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: 실패한 메시지가 있으면 true
    func hasFailedMessages(roomId: String) -> Bool {
        return repository.hasFailedMessages(roomId: roomId)
    }
}
