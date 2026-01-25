//
//  ChatRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation
import UIKit
import Combine
import CoreData
import AVFoundation

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
    /// 동작 (로컬 우선 전략):
    /// 1. CoreData에서 로컬 데이터를 먼저 가져와서 즉시 반환 (오프라인 지원)
    /// 2. 백그라운드에서 API 호출하여 최신 목록 가져오기
    /// 3. 성공 시 CoreData에 저장 (UPSERT)
    /// 4. Subject 업데이트로 UI 자동 갱신
    ///
    /// - Returns: [ChatRoom] (Domain Entity 배열) - 로컬 데이터 즉시 반환
    func fetchChatRooms() async throws -> [ChatRoom] {
        guard let userId = currentUserId else {
            throw RepositoryError.userNotLoggedIn
        }

        // 1. CoreData에서 로컬 데이터를 먼저 가져오기
        let localChatRooms: [ChatRoom]
        do {
            let entities = try coreDataManager.fetchChatRooms()
            localChatRooms = entities.map { $0.toDomain() }

            // 로컬 데이터가 있으면 즉시 Subject 업데이트 (빠른 UI 표시)
            if !localChatRooms.isEmpty {
                chatRoomsSubject.send(localChatRooms)
            }
        } catch {
            localChatRooms = []
        }

        // 2. 백그라운드에서 네트워크 요청 (비동기)
        Task {
            do {
                let router = ChatRouter.fetchChatRooms
                let responseDTO = try await networkManager.request(router, type: ChatRoomListResponseDTO.self)

                // DTO -> Domain Entity 변환
                let chatRooms = responseDTO.data.compactMap { $0.toDomain(currentUserId: userId) }

                // CoreData에 저장
                for chatRoom in chatRooms {
                    try saveChatRoomToCoreData(chatRoom)
                    if let lastMessage = chatRoom.lastMessage {
                        try saveMessageToCoreData(lastMessage)
                    }
                }

                // Subject 업데이트 (UI 자동 갱신)
                await refreshChatRoomsFromCoreData()

            } catch {
                // 네트워크 에러는 조용히 무시 (로컬 데이터가 이미 표시됨)
            }
        }

        // 3. 로컬 데이터 즉시 반환 (오프라인에서도 작동)
        return localChatRooms
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
    /// 동작 (로컬 우선 전략):
    /// 1. CoreData에서 로컬 메시지를 먼저 가져와서 즉시 반환 (오프라인 지원)
    /// 2. 백그라운드에서 API로 전체 메시지 요청 (next=nil로 시작)
    /// 3. 성공 시 CoreData에 저장
    /// 4. Subject 업데이트로 UI 자동 갱신
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    /// - Returns: [ChatMessage] (Domain Entity 배열) - 로컬 데이터 즉시 반환
    func fetchChatHistory(roomId: String) async throws -> [ChatMessage] {

        // 1. CoreData에서 로컬 메시지를 먼저 가져오기
        let localMessages: [ChatMessage]
        do {
            let entities = try coreDataManager.fetchMessages(for: roomId)
            localMessages = entities.map { $0.toDomain() }

            // 로컬 메시지가 있으면 즉시 Subject 업데이트 (빠른 UI 표시)
            if !localMessages.isEmpty {
                await refreshMessagesFromCoreData(roomId: roomId)
            }
        } catch {
            localMessages = []
        }

        // 2. 백그라운드에서 네트워크 요청 (비동기)
        Task {
            do {
                let router = ChatRouter.fetchChatHistory(roomId: roomId, next: nil)
                let responseDTO = try await networkManager.request(router, type: ChatHistoryResponseDTO.self)

                // DTO -> Domain Entity 변환
                let messages = responseDTO.data.map { $0.toDomain() }

                // CoreData에 저장
                for message in messages {
                    try saveMessageToCoreData(message)
                }

                // Subject 업데이트 (UI 자동 갱신)
                await refreshMessagesFromCoreData(roomId: roomId)

            } catch {
                // 네트워크 에러는 조용히 무시 (로컬 데이터가 이미 표시됨)
            }
        }

        // 3. 로컬 데이터 즉시 반환 (오프라인에서도 작동)
        return localMessages
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
    func sendMessage(roomId: String, content: String?, files: [String]) async throws -> ChatMessage {
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
    /// - 확장자: jpg, png, jpeg, gif, pdf, mp3, mp4, m4a, mov
    /// - 용량: 50MB
    /// - 개수: 5개
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    ///   - dataList: 업로드할 파일 데이터 배열
    ///   - fileExtensions: 각 파일의 확장자 배열
    /// - Returns: 업로드된 파일 URL 배열
    func uploadFiles(roomId: String, dataList: [Data], fileExtensions: [String]) async throws -> [String] {
        var allData: [Data] = []
        var allExtensions: [String] = []

        for (index, data) in dataList.enumerated() {
            let fileExtension = fileExtensions[index].lowercased()
            let isVideo = ["mp4", "mov", "m4a", "m4v"].contains(fileExtension)

            if isVideo && fileExtension != "mp4" {
                // 동영상이고 mp4가 아닌 경우: mp4로 변환 후 업로드
                do {
                    let mp4Data = try await convertVideoToMP4(from: data)
                    allData.append(mp4Data)
                    allExtensions.append("mp4")  // mov → mp4
                } catch {
                    continue
                }
            } else {
                // 이미 mp4이거나 이미지/기타 파일인 경우: 그대로 추가
                allData.append(data)
                allExtensions.append(fileExtension)
            }
        }

        guard !allData.isEmpty else {
            throw FileUploadError.noFiles
        }

        // 1. ChatRouter에 uploadFiles 엔드포인트 사용
        let endpoint = ChatRouter.uploadFiles(roomId: roomId, imageData: allData)

        // 2. NetworkManager의 확장자 지정 업로드 메서드 호출
        // FileUploadConfig.chat: jpg, png, jpeg, gif, pdf, mp3, mp4, m4a, mov (50MB, 5개)
        do {
            return try await networkManager.uploadFiles(
                allData,
                fileExtensions: allExtensions,
                config: .chat,
                endpoint: endpoint
            )
        } catch {
            if let networkError = error as? NetworkError,
               case .clientError(let statusCode, _) = networkError,
               statusCode == 400 {
                do {
                    return try await networkManager.uploadFiles(
                        allData,
                        fileExtensions: allExtensions,
                        config: .chatArray,
                        endpoint: endpoint
                    )
                } catch {
                    if let retryError = error as? NetworkError,
                       case .clientError(let retryStatus, _) = retryError,
                       retryStatus == 400 {
                        do {
                            return try await networkManager.uploadFiles(
                                allData,
                                fileExtensions: allExtensions,
                                config: .chatSingle,
                                endpoint: endpoint
                            )
                        } catch {
                            if let finalError = error as? NetworkError,
                               case .clientError(let finalStatus, _) = finalError,
                               finalStatus == 400,
                               allExtensions.allSatisfy({ FileUploadConfig.post.allowedExtensions.contains($0) }) {
                                return try await networkManager.uploadFiles(
                                    allData,
                                    fileExtensions: allExtensions,
                                    config: .post,
                                    endpoint: PostRouter.uploadFiles(imageData: allData)
                                )
                            }
                            throw error
                        }
                    }
                    throw error
                }
            }
            throw error
        }
    }

    /// 동영상 파일 Data를 mp4로 변환
    /// - Parameter videoData: 원본 동영상 Data (mov, m4v 등)
    /// - Returns: mp4로 변환된 Data
    private func convertVideoToMP4(from videoData: Data) async throws -> Data {
        // 1. Data를 임시 파일로 저장 (AVAsset은 URL이 필요함)
        let tempDirectory = FileManager.default.temporaryDirectory
        let inputURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mp4")

        try videoData.write(to: inputURL)

        defer {
            // 작업 완료 후 임시 파일들 삭제
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        // 2. AVAsset으로 동영상 로드
        let asset = AVAsset(url: inputURL)

        // 3. Export Session 생성 (고품질 프리셋)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw FileUploadError.noFiles
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4  // ✅ mp4로 변환
        exportSession.shouldOptimizeForNetworkUse = true

        // 4. 변환 시작 (async/await)
        await exportSession.export()

        // 5. 변환 결과 확인
        guard exportSession.status == .completed else {
            throw FileUploadError.noFiles
        }

        // 6. 변환된 mp4 파일을 Data로 읽기
        let mp4Data = try Data(contentsOf: outputURL)

        return mp4Data
    }

    /// 동영상 파일 Data로부터 첫 프레임 썸네일 생성
    /// - Parameter videoData: 동영상 파일 Data
    /// - Returns: 썸네일 JPEG Data
    private func generateVideoThumbnail(from videoData: Data) throws -> Data {
        // 1. Data를 임시 파일로 저장 (AVAsset은 URL이 필요함)
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mov")

        try videoData.write(to: tempFileURL)

        defer {
            // 2. 작업 완료 후 임시 파일 삭제
            try? FileManager.default.removeItem(at: tempFileURL)
        }

        // 3. AVAsset으로 동영상 로드
        let asset = AVAsset(url: tempFileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        // 4. 첫 프레임 추출 (0초)
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        let imageRef = try generator.copyCGImage(at: time, actualTime: nil)
        let thumbnailImage = UIImage(cgImage: imageRef)

        // 5. JPEG Data로 변환 (0.8 품질)
        guard let jpegData = thumbnailImage.jpegData(compressionQuality: 0.8) else {
            throw FileUploadError.noFiles
        }

        return jpegData
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
            try saveChatRoomToCoreData(chatRoom)

            // 3. lastMessage가 있으면 함께 저장
            if let lastMessage = chatRoom.lastMessage {
                try saveMessageToCoreData(lastMessage)
            }
        } else {
        }
    }

    /// CoreData의 변경사항을 디스크에 저장
    ///
    /// - Note: ensureChatRoomExists 호출 후 즉시 호출하여 relationship 설정 완료 보장
    func saveChatRoomContext() throws {
        try coreDataManager.saveContext()
    }

    /// 마지막 읽은 시간 업데이트
    ///
    /// - Parameter roomId: 채팅방 ID
    func updateLastReadDate(roomId: String) async throws {

        // CoreData에서 ChatRoomEntity 조회
        let fetchRequest = ChatRoomEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "roomId == %@", roomId)

        let results = try coreDataManager.viewContext.fetch(fetchRequest)
        guard let chatRoomEntity = results.first else {
            return
        }

        let beforeDate = chatRoomEntity.lastReadAt

        // lastReadAt 업데이트
        chatRoomEntity.lastReadAt = Date()

        try coreDataManager.saveContext()

        // 채팅방 목록 갱신 (배지 업데이트를 위해)
        await refreshChatRoomsFromCoreData()
    }

    /// 메시지 삭제 (CoreData에서만 삭제, 서버에는 영향 없음)
    ///
    /// 사용처:
    /// - 전송 실패한 메시지 재전송 전 기존 메시지 삭제
    ///
    /// - Parameter chatId: 삭제할 메시지 ID
    /// - Throws: CoreData 에러
    func deleteMessage(chatId: String) async throws {
        try deleteMessageFromCoreData(chatId: chatId)

        // 메시지 목록 갱신 (UI 업데이트)
        // roomId를 모르므로 전체 메시지 갱신은 불가능
        // 대신 삭제만 하고, observeMessages가 자동으로 갱신함
    }

    /// 특정 채팅방의 실패한 메시지 조회
    ///
    /// 조건:
    /// - status가 .failed인 메시지만
    /// - 24시간 이내
    /// - 최근 20개까지
    /// - createdAt 오름차순 (FIFO - 오래된 것부터)
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: 실패한 메시지 배열
    /// - Throws: CoreData 에러
    func fetchFailedMessages(roomId: String) async throws -> [ChatMessage] {
        let fetchRequest = ChatMessageEntity.fetchRequest()

        // 24시간 이내
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)

        // 조건: roomId 일치, status가 failed, 24시간 이내
        fetchRequest.predicate = NSPredicate(
            format: "roomId == %@ AND status == %@ AND createdAt >= %@",
            roomId,
            MessageSendStatus.failed.rawValue,
            twentyFourHoursAgo as NSDate
        )

        // 정렬: createdAt 오름차순 (FIFO - 오래된 것부터)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        // 최대 20개
        fetchRequest.fetchLimit = 20

        let results = try coreDataManager.viewContext.fetch(fetchRequest)

        return results.map { $0.toDomain() }
    }

    /// 특정 채팅방에 실패한 메시지가 있는지 확인
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: 실패한 메시지가 있으면 true
    func hasFailedMessages(roomId: String) -> Bool {
        let fetchRequest = ChatMessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "roomId == %@ AND status == %@",
            roomId,
            MessageSendStatus.failed.rawValue
        )
        fetchRequest.fetchLimit = 1

        do {
            let count = try coreDataManager.viewContext.count(for: fetchRequest)
            return count > 0
        } catch {
            return false
        }
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
    /// 1. CoreData에 이미 존재하는지 확인 (중복 방지)
    /// 2. .sending 상태의 로컬 임시 메시지 삭제 (Optimistic Update 정리)
    /// 3. 없을 때만 CoreData에 저장
    /// 4. 현재 채팅방 Subject 업데이트 (조건부)
    /// 5. 채팅방 목록 Subject 업데이트 (항상)
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
                        // 1. CoreData에 이미 존재하는지 확인 (중복 방지)
                        let fetchRequest = ChatMessageEntity.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "chatId == %@", message.chatId)

                        let results = try self.coreDataManager.viewContext.fetch(fetchRequest)

                        // 이미 존재하면 저장하지 않음 (API 응답으로 이미 저장된 메시지)
                        if !results.isEmpty {
                            return
                        }

                        // ✅ 2. .sending 상태의 로컬 임시 메시지 삭제 (중복 방지)
                        // - 같은 roomId + senderId + 비슷한 createdAt 시간을 가진 .sending 메시지 찾기
                        // - 이는 사용자가 방금 전송한 메시지의 임시 버전
                        let tempMessageRequest = ChatMessageEntity.fetchRequest()
                        tempMessageRequest.predicate = NSPredicate(
                            format: "roomId == %@ AND senderId == %@ AND status == %@",
                            message.roomId,
                            message.senderId,
                            MessageSendStatus.sending.rawValue
                        )

                        let tempMessages = try self.coreDataManager.viewContext.fetch(tempMessageRequest)

                        // 시간 차이가 5초 이내인 메시지를 찾음 (같은 메시지로 간주)
                        let fiveSecondsAgo = Date().addingTimeInterval(-5)
                        for tempMessage in tempMessages {
                            if let tempCreatedAt = tempMessage.createdAt,
                               tempCreatedAt >= fiveSecondsAgo {
                                self.coreDataManager.viewContext.delete(tempMessage)
                            }
                        }

                        // 3. CoreData에 저장 (존재하지 않을 때만)
                        try self.saveMessageToCoreData(message)

                        // 4. 현재 채팅방 Subject가 있으면 업데이트
                        // - 사용자가 해당 채팅방에 있을 때만 실시간 업데이트
                        // - Subject가 없으면 불필요한 생성 방지
                        if self.messagesSubjects[message.roomId] != nil {
                            await self.refreshMessagesFromCoreData(roomId: message.roomId)
                        }

                        // 5. 채팅방 목록도 항상 업데이트
                        // - lastMessage, updatedAt 변경 반영
                        // - 채팅방 목록 화면에서 실시간 갱신
                        await self.refreshChatRoomsFromCoreData()

                    } catch {
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

        // lastReadAt은 기존 값이 더 최신이면 유지 (로컬에서 읽은 시간을 서버 데이터로 덮어쓰지 않음)
        if let existingLastReadAt = entity.lastReadAt,
           let newLastReadAt = chatRoom.lastReadAt {
            // 둘 다 있으면 더 최신 값 사용
            entity.lastReadAt = max(existingLastReadAt, newLastReadAt)
        } else if chatRoom.lastReadAt != nil {
            // 새 값만 있으면 새 값 사용
            entity.lastReadAt = chatRoom.lastReadAt
        } else {
            // 기존 값만 있거나 둘 다 없으면 기존 값 유지
        }

        // 3. 저장
        try coreDataManager.saveContext()
    }

    /// ChatMessage를 CoreData에 저장
    ///
    /// - Note:
    ///   1. files는 이제 Transformable 타입으로 자동 변환되므로 직접 전달
    ///   2. 메시지 저장 전에 항상 ChatRoom이 존재하는지 확인 (크래시 방지)
    private func saveMessageToCoreData(_ message: ChatMessage) throws {
        // ✅ 1. ChatRoom이 존재하는지 확인
        let chatRoomFetchRequest = ChatRoomEntity.fetchRequest()
        chatRoomFetchRequest.predicate = NSPredicate(format: "roomId == %@", message.roomId)
        let existingChatRooms = try coreDataManager.viewContext.fetch(chatRoomFetchRequest)

        // ✅ 2. ChatRoom이 없으면 최소한의 정보로 생성
        if existingChatRooms.isEmpty {
            _ = try coreDataManager.upsertChatRoom(
                roomId: message.roomId,
                createdAt: message.createdAt,
                updatedAt: message.createdAt
            )
            // 즉시 저장하여 relationship 설정 가능하도록 보장
            try coreDataManager.saveContext()
        }

        // ✅ 3. 메시지 저장 (이제 ChatRoom이 확실히 존재함)
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
