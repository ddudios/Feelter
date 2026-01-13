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

        guard let chatRoom = responseDTO.toDomain(currentUserId: userId) else {
            // 자기 자신과의 채팅방인 경우
            throw RepositoryError.invalidChatRoom
        }

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

        // 2. DTO -> Domain Entity 변환 (자기 자신과의 채팅방 필터링)
        let chatRooms = responseDTO.data.compactMap { $0.toDomain(currentUserId: userId) }

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
    /// 1. API로 전체 메시지 요청 (next=nil로 시작)
    /// 2. CoreData에 저장
    /// 3. Subject 업데이트
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    /// - Returns: [ChatMessage] (Domain Entity 배열)
    func fetchChatHistory(roomId: String) async throws -> [ChatMessage] {
        print("📥 [Repository] 채팅 내역 조회 시작: roomId=\(roomId)")

        // API 호출 (next=nil: 전체 내역 조회)
        let router = ChatRouter.fetchChatHistory(roomId: roomId, next: nil)

        do {
            let responseDTO = try await networkManager.request(router, type: ChatHistoryResponseDTO.self)
            print("✅ [Repository] API 응답 성공: data.count=\(responseDTO.data.count)")

            // DTO -> Domain Entity 변환
            let messages = responseDTO.data.map { $0.toDomain() }
            print("📦 [Repository] 메시지 변환 완료: messages.count=\(messages.count)")

            // CoreData에 저장
            for message in messages {
                try saveMessageToCoreData(message)
            }

            // Subject 업데이트
            await refreshMessagesFromCoreData(roomId: roomId)

            // CoreData에서 전체 메시지 반환
            let allEntities = try coreDataManager.fetchMessages(for: roomId)
            print("✅ [Repository] 전체 메시지 반환: count=\(allEntities.count)")
            return allEntities.map { $0.toDomain() }

        } catch {
            print("❌ [Repository] 채팅 내역 조회 실패: \(error)")
            print("   - Error Type: \(type(of: error))")
            print("   - Error Description: \(error.localizedDescription)")
            throw error
        }
    }

    /// 특정 채팅방의 메시지 실시간 감지
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: Publisher<[ChatMessage], Never>
    func observeMessages(roomId: String) -> AnyPublisher<[ChatMessage], Never> {
        // Subject가 없으면 생성
        if messagesSubjects[roomId] == nil {
            // ✅ CoreData에서 초기 메시지를 먼저 로드
            let initialMessages: [ChatMessage]
            do {
                let entities = try coreDataManager.fetchMessages(for: roomId)
                initialMessages = entities.map { $0.toDomain() }
            } catch {
                initialMessages = []
            }

            // ✅ 로드된 데이터로 Subject 생성
            messagesSubjects[roomId] = CurrentValueSubject<[ChatMessage], Never>(initialMessages)
        } else {
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
        // 1. ChatRouter에 uploadFiles 엔드포인트 사용
        let endpoint = ChatRouter.uploadFiles(roomId: roomId, imageData: imageData)

        // 2. NetworkManager의 config 기반 업로드 메서드 호출
        // FileUploadConfig.chat: jpg, png, jpeg, gif, pdf (5MB, 5개)
        return try await networkManager.uploadFiles(
            imageData,
            config: .chat,
            endpoint: endpoint
        )
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

    /// 채팅방이 CoreData에 존재하는지 확인하고, 없으면 저장
    ///
    /// - Parameter chatRoom: 저장할 채팅방 정보
    func ensureChatRoomExists(_ chatRoom: ChatRoom) throws {
        // 1. 이미 존재하는지 확인
        let fetchRequest = ChatRoomEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "roomId == %@", chatRoom.roomId)

        let results = try coreDataManager.viewContext.fetch(fetchRequest)

        if results.isEmpty {
            // 2. 존재하지 않으면 저장
            print("📝 [Repository] 채팅방을 CoreData에 저장: roomId=\(chatRoom.roomId)")
            try saveChatRoomToCoreData(chatRoom)

            // 3. lastMessage가 있으면 함께 저장
            if let lastMessage = chatRoom.lastMessage {
                try saveMessageToCoreData(lastMessage)
            }
        } else {
            print("✅ [Repository] 채팅방이 이미 CoreData에 존재: roomId=\(chatRoom.roomId)")
        }
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
    ///
    /// Socket에서 새 메시지 수신 시 동작:
    /// 1. CoreData에 저장 (항상)
    /// 2. 현재 채팅방 Subject 업데이트 (조건부)
    /// 3. 채팅방 목록 Subject 업데이트 (항상)
    private func setupSocketMessageListener() {
        socketManager.observeMessages()
            .sink { [weak self] messageDTO in
                guard let self = self else { return }

                // DTO -> Domain Entity 변환
                let message = messageDTO.toDomain()

                // ✅ CoreData는 메인 스레드에서만 접근 (viewContext 사용)
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    do {
                        // 1. CoreData에 저장 (항상)
                        try self.saveMessageToCoreData(message)

                        // 2. 현재 채팅방 Subject가 있으면 업데이트
                        // - 사용자가 해당 채팅방에 있을 때만 실시간 업데이트
                        // - Subject가 없으면 불필요한 생성 방지
                        if self.messagesSubjects[message.roomId] != nil {
                            await self.refreshMessagesFromCoreData(roomId: message.roomId)
                        } else {
                        }

                        // 3. 채팅방 목록도 항상 업데이트
                        // - lastMessage, updatedAt 변경 반영
                        // - 채팅방 목록 화면에서 실시간 갱신
                        await self.refreshChatRoomsFromCoreData()

                    } catch {
                        // Error handling is intentionally silent; other paths handle user-facing alerts.
                    }
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
    ///
    /// - Note: files는 이제 Transformable 타입으로 자동 변환되므로 직접 전달
    private func saveMessageToCoreData(_ message: ChatMessage) throws {
        _ = try coreDataManager.upsertChatMessage(
            chatId: message.chatId,
            roomId: message.roomId,
            content: message.content,
            senderId: message.senderId,
            senderNick: message.senderNick,
            senderProfileImage: message.senderProfileImage,
            createdAt: message.createdAt,
            files: message.files.isEmpty ? nil : message.files,  // ✅ 직접 전달 (빈 배열은 nil로)
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
            // Error logged upstream if needed
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
            // Error logged upstream if needed
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case userNotLoggedIn
    case messageNotFound
    case invalidResponse
    case invalidChatRoom

    var errorDescription: String? {
        switch self {
        case .userNotLoggedIn:
            return "로그인이 필요합니다."
        case .messageNotFound:
            return "메시지를 찾을 수 없습니다."
        case .invalidResponse:
            return "잘못된 응답입니다."
        case .invalidChatRoom:
            return "유효하지 않은 채팅방입니다."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 재로그인 필요 (토큰 만료, 인증 실패 등)
    static let requiresReauthentication = Notification.Name("requiresReauthentication")
}
