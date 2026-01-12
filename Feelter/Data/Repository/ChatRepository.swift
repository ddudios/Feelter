//
//  ChatRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation
import Combine
import CoreData

/// ChatRepository: 채팅 데이터 관리
///
/// 역할:
/// 1. API + CoreData + Socket.IO를 통합하여 단일 인터페이스 제공
/// 2. Domain Layer에 Domain Entity 반환 (DTO 변환)
/// 3. 데이터 정합성 보장 (UPSERT)
///
/// 데이터 흐름:
/// - 읽기: CoreData -> API -> CoreData 저장 -> Domain Entity 반환
/// - 실시간: Socket.IO -> CoreData 저장 -> Publisher 방출
/// - 쓰기: API 전송 -> 성공 시 CoreData 저장
///
final class ChatRepository: ChatRepositoryProtocol {

    // MARK: - Dependencies
    /// API 호출
    private let networkManager: NetworkManagerProtocol

    /// 로컬 저장소
    private let coreDataManager: CoreDataManager

    /// 실시간 메시지 수신
    private let socketManager: SocketIOManager

    /// 현재 사용자 ID (채팅방에서 상대방 찾기 위해 필요)
    private var currentUserId: String? {
        // KeychainManager에서 userId 조회
        // TODO: 실제 키 이름 확인 필요
        return KeychainManager.shared.read(account: "userId")
    }

    // MARK: - Combine Subjects

    /// 채팅방 목록 변경 감지
    /// CurrentValueSubject: 초기값을 가지며, 마지막 값을 저장
    private let chatRoomsSubject = CurrentValueSubject<[ChatRoom], Never>([])

    /// 특정 채팅방의 메시지 변경 감지
    /// Key: roomId, Value: 메시지 배열
    private var messagesSubjects: [String: CurrentValueSubject<[ChatMessage], Never>] = [:]

    /// Cancellables 저장소
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(
        networkManager: NetworkManagerProtocol = NetworkManager(),
        coreDataManager: CoreDataManager = .shared,
        socketManager: SocketIOManager = .shared
    ) {
        self.networkManager = networkManager
        self.coreDataManager = coreDataManager
        self.socketManager = socketManager

        // Socket.IO 메시지 구독 설정
        setupSocketMessageListener()

        // Socket.IO 에러 구독 설정
        setupSocketErrorListener()
    }

    // MARK: - ChatRepositoryProtocol Implementation
    /// 채팅방 생성 또는 조회
    ///
    /// 동작:
    /// 1. API 호출: POST /v1/chats
    /// 2. 응답 DTO -> Domain Entity 변환
    /// 3. CoreData에 저장 (상대방 정보 포함)
    ///
    /// - Parameter opponentId: 상대방 user_id
    /// - Returns: ChatRoom (Domain Entity)
    func createOrFetchChatRoom(opponentId: String) async throws -> ChatRoom {
        // 1. API 호출
        let router = ChatRouter.createChatRoom(opponentId: opponentId)
        let responseDTO = try await networkManager.request(router, type: ChatRoomResponseDTO.self)

        // 2. DTO -> Domain Entity 변환
        guard let userId = currentUserId else {
            throw RepositoryError.userNotLoggedIn
        }
        let chatRoom = responseDTO.toDomain(currentUserId: userId)

        // 3. CoreData에 저장
        try saveChatRoomToCoreData(chatRoom)
        if let lastMessage = chatRoom.lastMessage {
            try saveMessageToCoreData(lastMessage)
        }

        // 4. Subject 업데이트 (채팅방 목록 갱신)
        await refreshChatRoomsFromCoreData()

        return chatRoom
    }

    /// 채팅방 목록 조회
    ///
    /// 동작:
    /// 1. CoreData에서 기존 목록 가져오기 (캐시)
    /// 2. API 호출하여 최신 목록 가져오기
    /// 3. CoreData에 저장 (UPSERT)
    /// 4. Subject 업데이트
    ///
    /// - Returns: [ChatRoom] (Domain Entity 배열)
    func fetchChatRooms() async throws -> [ChatRoom] {
        guard let userId = currentUserId else {
            throw RepositoryError.userNotLoggedIn
        }

        // 1. API 호출
        let router = ChatRouter.fetchChatRooms
        let responseDTO = try await networkManager.request(router, type: ChatRoomListResponseDTO.self)

        // 2. DTO -> Domain Entity 변환
        let chatRooms = responseDTO.data.map { $0.toDomain(currentUserId: userId) }

        // 3. CoreData에 저장
        for chatRoom in chatRooms {
            try saveChatRoomToCoreData(chatRoom)
            if let lastMessage = chatRoom.lastMessage {
                try saveMessageToCoreData(lastMessage)
            }
        }

        // 4. Subject 업데이트
        chatRoomsSubject.send(chatRooms)

        return chatRooms
    }

    /// 채팅방 목록 실시간 감지
    ///
    /// CoreData 변경을 감지하여 UI 업데이트
    ///
    /// - Returns: Publisher<[ChatRoom], Never>
    func observeChatRooms() -> AnyPublisher<[ChatRoom], Never> {
        return chatRoomsSubject.eraseToAnyPublisher()
    }

    /// 채팅 내역 조회
    ///
    /// 동작:
    /// 1. CoreData에서 기존 메시지 가져오기
    /// 2. API로 최신 메시지 요청 (next 파라미터 사용)
    /// 3. CoreData에 저장
    /// 4. Subject 업데이트
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    ///   - next: 페이지네이션용 날짜 (옵셔널)
    /// - Returns: [ChatMessage] (Domain Entity 배열)
    func fetchChatHistory(roomId: String) async throws -> [ChatMessage] {
        // 1. CoreData에서 마지막 메시지 시간 조회
        let lastMessageDate = coreDataManager.fetchLastMessageDate(for: roomId)

        // 2. ISO 8601 String으로 변환 (next 파라미터)
        let next = lastMessageDate.map { ISO8601DateParser.string(from: $0) }

        // 3. API 호출
        let router = ChatRouter.fetchChatHistory(roomId: roomId, next: next)
        let responseDTO = try await networkManager.request(router, type: ChatRoomListResponseDTO.self)

        // 4. DTO -> Domain Entity 변환
        let messages = responseDTO.data.compactMap { chatRoomDTO in
            chatRoomDTO.lastChat?.toDomain()
        }

        // 5. CoreData에 저장
        for message in messages {
            try saveMessageToCoreData(message)
        }

        // 6. Subject 업데이트
        await refreshMessagesFromCoreData(roomId: roomId)

        // 7. CoreData에서 전체 메시지 반환
        let allEntities = try coreDataManager.fetchMessages(for: roomId)
        return allEntities.map { $0.toDomain() }
    }

    /// 특정 채팅방의 메시지 실시간 감지
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: Publisher<[ChatMessage], Never>
    func observeMessages(roomId: String) -> AnyPublisher<[ChatMessage], Never> {
        // Subject가 없으면 생성
        if messagesSubjects[roomId] == nil {
            messagesSubjects[roomId] = CurrentValueSubject<[ChatMessage], Never>([])

            // CoreData에서 초기 메시지 로드
            Task {
                await refreshMessagesFromCoreData(roomId: roomId)
            }
        }

        return messagesSubjects[roomId]!.eraseToAnyPublisher()
    }

    /// 메시지 전송
    ///
    /// 동작:
    /// 1. Optimistic Update: 로컬에 .sending 상태로 저장
    /// 2. API 전송: POST /v1/chats/{room_id}
    /// 3. 성공: 로컬 임시 메시지 삭제 후 서버 응답 저장
    /// 4. 실패: .failed 상태로 업데이트
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    ///   - content: 메시지 내용
    ///   - files: 첨부 파일 (옵셔널)
    /// - Returns: ChatMessage (전송된 메시지)
    func sendMessage(roomId: String, content: String, files: [String]) async throws -> ChatMessage {
        guard let userId = currentUserId else {
            throw RepositoryError.userNotLoggedIn
        }

        // 1. Optimistic Update: 로컬 메시지 생성
        let localMessage = ChatMessage.createLocal(
            roomId: roomId,
            content: content,
            senderId: userId,
            senderNick: "나",  // TODO: 실제 닉네임 가져오기
            files: files
        )

        // 2. CoreData에 .sending 상태로 저장
        try saveMessageToCoreData(localMessage)
        await refreshMessagesFromCoreData(roomId: roomId)

        do {
            // 3. API 전송
            let router = ChatRouter.sendMessage(roomId: roomId, content: content, files: files.isEmpty ? nil : files)
            let responseDTO = try await networkManager.request(router, type: ChatMessageResponseDTO.self)

            // 4. 성공: 로컬 임시 메시지 삭제
            try deleteMessageFromCoreData(chatId: localMessage.chatId)

            // 5. 서버 응답으로 저장
            let sentMessage = responseDTO.toDomain()
            try saveMessageToCoreData(sentMessage)
            await refreshMessagesFromCoreData(roomId: roomId)

            return sentMessage

        } catch {
            // 6. 실패: .failed 상태로 업데이트
            let failedMessage = localMessage.with(status: .failed)
            try saveMessageToCoreData(failedMessage)
            await refreshMessagesFromCoreData(roomId: roomId)

            throw error
        }
    }

    /// 채팅방 파일 업로드
    ///
    /// 동작:
    /// 1. 파일을 multipart/form-data로 업로드
    /// 2. 서버가 파일 URL 배열 반환
    /// 3. 이 URL을 sendMessage()의 files 파라미터로 사용
    ///
    /// 제약사항:
    /// - 확장자: jpg, png, jpeg, gif, pdf
    /// - 용량: 5MB
    /// - 개수: 5개
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    ///   - imageData: 업로드할 이미지/파일 데이터 배열
    /// - Returns: 업로드된 파일 URL 배열
    func uploadFiles(roomId: String, imageData: [Data]) async throws -> [String] {
        // TODO: multipart/form-data 업로드 구현
        // NetworkManager에서 별도 처리 필요

        // 임시 구현: 빈 배열 반환
        // 실제로는 ChatRouter에 uploadFiles case 추가하고
        // NetworkManager에 multipart upload 메서드 추가 필요

        throw RepositoryError.invalidResponse
    }

    /// Socket.IO 연결
    ///
    /// - Parameter roomId: 채팅방 ID
    func connectSocket(roomId: String) {
        socketManager.connect(to: roomId)
    }

    /// Socket.IO 연결 해제
    func disconnectSocket() {
        socketManager.disconnect()
    }

    /// 마지막 읽은 시간 업데이트
    ///
    /// - Parameter roomId: 채팅방 ID
    func updateLastReadDate(roomId: String) throws {
        // CoreData에서 ChatRoomEntity 조회
        let fetchRequest = ChatRoomEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "roomId == %@", roomId)

        let results = try coreDataManager.viewContext.fetch(fetchRequest)
        guard let chatRoomEntity = results.first else { return }

        // lastReadAt 업데이트
        chatRoomEntity.lastReadAt = Date()
        try coreDataManager.saveContext()
    }

    /// 실패한 메시지 재전송
    ///
    /// - Parameter chatId: 재전송할 메시지 ID
    /// - Returns: ChatMessage (재전송된 메시지)
    func retryFailedMessage(chatId: String) async throws -> ChatMessage {
        // CoreData에서 메시지 조회
        let fetchRequest = ChatMessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "chatId == %@", chatId)

        let results = try coreDataManager.viewContext.fetch(fetchRequest)
        guard let messageEntity = results.first else {
            throw RepositoryError.messageNotFound
        }

        let message = messageEntity.toDomain()

        // 재전송
        return try await sendMessage(
            roomId: message.roomId,
            content: message.content,
            files: message.files
        )
    }

    // MARK: - Private Helpers
    /// Socket.IO 메시지 리스너 설정
    private func setupSocketMessageListener() {
        socketManager.observeMessages()
            .sink { [weak self] messageDTO in
                guard let self = self else { return }

                // DTO -> Domain Entity 변환
                let message = messageDTO.toDomain()

                // CoreData에 저장
                do {
                    try self.saveMessageToCoreData(message)

                    // Subject 업데이트
                    Task {
                        await self.refreshMessagesFromCoreData(roomId: message.roomId)
                    }
                } catch {
                    print("Socket 메시지 저장 실패: \(error)")
                }
            }
            .store(in: &cancellables)
    }

    /// Socket.IO 에러 리스너 설정
    private func setupSocketErrorListener() {
        socketManager.observeErrors()
            .sink { [weak self] error in
                guard let self = self else { return }

                if error.requiresReauthentication {
                    // 재로그인 필요
                    // NotificationCenter로 앱 전체에 알림
                    NotificationCenter.default.post(
                        name: .requiresReauthentication,
                        object: nil,
                        userInfo: ["error": error]
                    )
                } else {
                    // 일반 에러 로그
                    print("Socket 에러: \(error.localizedDescription ?? "")")
                }
            }
            .store(in: &cancellables)
    }

    /// ChatRoom을 CoreData에 저장
    private func saveChatRoomToCoreData(_ chatRoom: ChatRoom) throws {
        // 1. ChatRoomEntity 생성 또는 조회
        let entity = try coreDataManager.upsertChatRoom(
            roomId: chatRoom.roomId,
            createdAt: chatRoom.createdAt,
            updatedAt: chatRoom.updatedAt
        )

        // 2. 상대방 정보 설정 (반환된 entity에 바로 설정)
        entity.opponentUserId = chatRoom.opponent.userId
        entity.opponentNick = chatRoom.opponent.nick
        entity.opponentProfileImage = chatRoom.opponent.profileImage
        entity.lastReadAt = chatRoom.lastReadAt

        // 3. 저장
        try coreDataManager.saveContext()
    }

    /// ChatMessage를 CoreData에 저장
    private func saveMessageToCoreData(_ message: ChatMessage) throws {
        // files 배열 -> JSON String 변환
        let filesJSON = try? JSONEncoder().encode(message.files)
        let filesString = filesJSON.flatMap { String(data: $0, encoding: .utf8) }

        _ = try coreDataManager.upsertChatMessage(
            chatId: message.chatId,
            roomId: message.roomId,
            content: message.content,
            senderId: message.senderId,
            senderNick: message.senderNick,
            senderProfileImage: message.senderProfileImage,
            createdAt: message.createdAt,
            files: filesString,
            status: message.status.rawValue
        )

        try coreDataManager.saveContext()
    }

    /// CoreData에서 메시지 삭제
    ///
    /// - Parameter chatId: 삭제할 메시지의 chatId
    private func deleteMessageFromCoreData(chatId: String) throws {
        let fetchRequest = ChatMessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "chatId == %@", chatId)

        let results = try coreDataManager.viewContext.fetch(fetchRequest)

        if let messageToDelete = results.first {
            coreDataManager.viewContext.delete(messageToDelete)
            try coreDataManager.saveContext()
        }
    }

    /// CoreData에서 채팅방 목록 갱신
    @MainActor
    private func refreshChatRoomsFromCoreData() async {
        do {
            guard let userId = currentUserId else { return }

            let entities = try coreDataManager.fetchChatRooms()
            let chatRooms = entities.map { $0.toDomain() }

            chatRoomsSubject.send(chatRooms)
        } catch {
            print("채팅방 목록 갱신 실패: \(error)")
        }
    }

    /// CoreData에서 메시지 목록 갱신
    @MainActor
    private func refreshMessagesFromCoreData(roomId: String) async {
        do {
            let entities = try coreDataManager.fetchMessages(for: roomId)
            let messages = entities.map { $0.toDomain() }

            messagesSubjects[roomId]?.send(messages)
        } catch {
            print("메시지 목록 갱신 실패: \(error)")
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case userNotLoggedIn
    case messageNotFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .userNotLoggedIn:
            return "로그인이 필요합니다."
        case .messageNotFound:
            return "메시지를 찾을 수 없습니다."
        case .invalidResponse:
            return "잘못된 응답입니다."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 재로그인 필요 (토큰 만료, 인증 실패 등)
    static let requiresReauthentication = Notification.Name("requiresReauthentication")
}
