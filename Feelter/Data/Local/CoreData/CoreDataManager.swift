//
//  CoreDataManager.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation
import CoreData

/// CoreData 에러 타입
enum CoreDataError: LocalizedError {
    case chatRoomNotFound(roomId: String)
    case invalidContext
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .chatRoomNotFound(let roomId):
            return "채팅방을 찾을 수 없습니다: \(roomId)"
        case .invalidContext:
            return "유효하지 않은 Context입니다."
        case .saveFailed(let error):
            return "저장 실패: \(error.localizedDescription)"
        }
    }
}

/// CoreData Stack을 관리하는 매니저 클래스
/// 1. NSPersistentContainer 생성 및 관리
/// 2. Context 제공 (Main Thread용, Background용)
/// 3. 저장/조회/삭제 등 기본 CRUD 메서드 제공
///
///
final class CoreDataManager {
    
    static let shared = CoreDataManager()

    // MARK: - Properties
    /// NSPersistentContainer: CoreData의 모든 구성 요소를 관리
    /// - 모델 (Model)
    /// - 코디네이터 (Persistent Store Coordinator)
    /// - Context (Managed Object Context)
    private let container: NSPersistentContainer

    /// Main Thread Context (UI 업데이트용)
    /// - UI는 반드시 Main Thread에서 업데이트되어야 함
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    // MARK: - Initialization
    /// CoreDataManager 초기화
    /// - Parameter modelName: .xcdatamodeld 파일 이름 (확장자 제외)
    /// - 기본값: "FeelterChat"
    /// Singleton 패턴을 사용하지만, 테스트를 위해 init도 public으로 제공
    init(modelName: String = "FeelterChat") {
        // 1. NSPersistentContainer 생성
        // 이름은 .xcdatamodeld 파일 이름과 일치해야 함
        container = NSPersistentContainer(name: modelName)

        // 2. Persistent Store 로드 (SQLite 파일 연결)
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("CoreData Store 로드 실패: \(error), \(error.userInfo)")
            }

            // 로드 성공 시 로그 (개발 중에만)
            #if DEBUG
            #endif
        }

        // 3. Merge Policy 설정 (중복 처리 전략)
        // - API와 Socket에서 같은 데이터가 중복으로 올 수 있음
        // - chatId가 중복이면 새로운 데이터로 덮어쓰기 (UPSERT)
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Context Management
    /// Background Thread용 Context 생성
    /// - 대용량 데이터 저장/조회 (UI가 멈추면 안 됨)
    /// - API 응답을 DB에 저장할 때
    /// - Socket 메시지를 DB에 저장할 때
    ///
    /// 주의사항:
    /// - NSManagedObject는 Thread 간 전달 불가!
    /// - objectID만 전달하고 각 Context에서 fetch
    ///
    /// - Returns: 새로운 Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Save

    /// Context의 변경사항을 디스크에 저장
    /// 언제 호출하는가?
    /// - Entity를 생성/수정/삭제한 후
    /// - 주의: 너무 자주 호출하면 성능 저하
    ///
    /// Thread-Safety:
    /// - NSManagedObjectContext는 thread-safe하지 않음
    /// - performAndWait을 사용해 context의 스레드에서 save() 실행
    ///
    /// - Parameter context: 저장할 Context (기본값: viewContext)
    /// - Throws: CoreData 저장 에러
    func saveContext(_ context: NSManagedObjectContext? = nil) throws {
        let contextToSave = context ?? viewContext

        // hasChanges: 변경사항이 있을 때만 저장 (성능 최적화)
        guard contextToSave.hasChanges else { return }

        var saveError: Error?

        // ✅ Context의 스레드에서 save() 실행 (thread-safety 보장)
        contextToSave.performAndWait {
            do {
                try contextToSave.save()
            } catch {
                #if DEBUG
                print("❌ CoreData 저장 실패: \(error)")
                #endif
                saveError = error
            }
        }

        if let saveError = saveError {
            throw saveError
        }
    }

    // MARK: - Delete All

    /// 특정 Entity의 모든 데이터 삭제 (개발/테스트용)
    /// 경고: 복구 불가능!
    /// "오래된 데이터 정리" 혹은 "전체 캐시 삭제" 기능
    /// 로그아웃
    /// - Parameter entityName: 삭제할 Entity 이름 (예: "ChatMessageEntity")
    func deleteAll(entityName: String) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        try viewContext.execute(deleteRequest)
        try saveContext()

        #if DEBUG
        #endif
    }
}

// MARK: - Chat Specific Methods
extension CoreDataManager {

    /// 채팅방의 마지막 메시지 시간 조회
    /// - API 요청 시 next 파라미터로 사용
    /// - 이 시간 이후의 메시지만 가져와서 효율성 증가
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: 마지막 메시지 시간 (없으면 nil)
    func fetchLastMessageDate(for roomId: String) -> Date? {
        let fetchRequest = ChatMessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "roomId == %@", roomId)  // 필터
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]  // 정렬
        fetchRequest.fetchLimit = 1 // 최신 1개만

        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first?.createdAt
        } catch {
            return nil
        }
    }

    /// 채팅방 목록 조회 (updatedAt 기준 최신순)
    ///
    /// - Returns: ChatRoomEntity 배열
    func fetchChatRooms() throws -> [ChatRoomEntity] {
        let fetchRequest = ChatRoomEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        var result: [ChatRoomEntity] = []
        var fetchError: Error?

        viewContext.performAndWait {
            do {
                result = try viewContext.fetch(fetchRequest)
            } catch {
                fetchError = error
            }
        }

        if let fetchError = fetchError {
            throw fetchError
        }

        return result
    }

    /// 특정 채팅방의 메시지 조회
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: ChatMessageEntity 배열 (오래된 순)
    func fetchMessages(for roomId: String) throws -> [ChatMessageEntity] {
        let fetchRequest = ChatMessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "roomId == %@", roomId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        var result: [ChatMessageEntity] = []
        var fetchError: Error?

        viewContext.performAndWait {
            do {
                result = try viewContext.fetch(fetchRequest)
            } catch {
                fetchError = error
            }
        }

        if let fetchError = fetchError {
            throw fetchError
        }

        return result
    }

    /// 모든 채팅방의 읽지 않은 메시지 개수를 한 번에 조회 (Batch Query)
    ///
    /// 동작 원리:
    /// 1. 모든 채팅방의 roomId와 lastReadAt 조회
    /// 2. 각 채팅방마다 CoreData count query 실행 (메모리에 로드하지 않음)
    /// 3. Dictionary로 반환: [roomId: unreadCount]
    ///
    /// 성능 최적화:
    /// - count(for:) 사용: 실제 데이터를 메모리에 로드하지 않고 SQLite COUNT만 실행
    /// - 채팅방 100개여도 100번의 가벼운 COUNT 쿼리 (각 쿼리는 1ms 미만)
    /// - 전체 소요 시간: ~10-50ms (채팅방 목록 표시 시 무시 가능한 수준)
    ///
    /// - Parameter currentUserId: 현재 사용자 ID (내가 보낸 메시지는 제외)
    /// - Returns: [roomId: unreadCount] Dictionary
    func fetchUnreadMessageCounts(currentUserId: String) throws -> [String: Int] {
        var unreadCounts: [String: Int] = [:]
        var fetchError: Error?

        viewContext.performAndWait {
            do {
                // 1. 모든 채팅방 조회 (roomId, lastReadAt만 필요)
                let chatRoomFetchRequest = ChatRoomEntity.fetchRequest()
                chatRoomFetchRequest.propertiesToFetch = ["roomId", "lastReadAt"]  // 필요한 속성만 조회 (최적화)
                let chatRooms = try viewContext.fetch(chatRoomFetchRequest)

                // 2. 각 채팅방마다 읽지 않은 메시지 개수 계산
                for chatRoom in chatRooms {
                    guard let roomId = chatRoom.roomId else { continue }

                    // 3. 읽지 않은 메시지 조건 설정
                    let messageFetchRequest = ChatMessageEntity.fetchRequest()

                    if let lastReadAt = chatRoom.lastReadAt {
                        // lastReadAt이 있으면: 그 이후 + 상대방이 보낸 + 전송 성공한 메시지만
                        // ✅ status == "sent" 추가: .sending, .failed 메시지 제외
                        messageFetchRequest.predicate = NSPredicate(
                            format: "roomId == %@ AND senderId != %@ AND createdAt > %@ AND status == %@",
                            roomId,
                            currentUserId,
                            lastReadAt as NSDate,
                            MessageSendStatus.sent.rawValue
                        )
                    } else {
                        // lastReadAt이 없으면: 상대방이 보낸 + 전송 성공한 모든 메시지
                        messageFetchRequest.predicate = NSPredicate(
                            format: "roomId == %@ AND senderId != %@ AND status == %@",
                            roomId,
                            currentUserId,
                            MessageSendStatus.sent.rawValue
                        )
                    }

                    // 4. count(for:) 사용: 실제 데이터를 메모리에 로드하지 않고 COUNT만 실행
                    // 이 방법이 fetch() 후 count보다 훨씬 빠름!
                    do {
                        let count = try viewContext.count(for: messageFetchRequest)
                        unreadCounts[roomId] = count
                    } catch {
                        // 특정 채팅방 count 실패 시 0으로 처리 (전체 로직은 계속 진행)
                        unreadCounts[roomId] = 0
                    }
                }
            } catch {
                fetchError = error
            }
        }

        if let fetchError = fetchError {
            throw fetchError
        }

        return unreadCounts
    }

    /// 모든 채팅방의 읽지 않은 메시지 개수를 마지막 읽은 메시지 ID 기준으로 조회
    ///
    /// 동작 원리:
    /// 1. UserDefaults에서 각 채팅방의 lastReadMessageId 가져오기
    /// 2. 각 채팅방마다 lastReadMessageId 이후의 메시지 개수 계산
    /// 3. Dictionary로 반환: [roomId: unreadCount]
    ///
    /// 서버에서 읽음 처리를 지원하지 않는 경우:
    /// - 로컬에 lastReadMessageId 저장 (UserDefaults)
    /// - CoreData에서 해당 메시지 이후의 메시지만 카운팅
    ///
    /// - Parameters:
    ///   - currentUserId: 현재 사용자 ID (내가 보낸 메시지는 제외)
    ///   - lastReadMessageIds: [roomId: lastReadMessageId] Dictionary
    /// - Returns: [roomId: unreadCount] Dictionary
    func fetchUnreadMessageCountsByMessageId(
        currentUserId: String,
        lastReadMessageIds: [String: String]
    ) throws -> [String: Int] {
        var unreadCounts: [String: Int] = [:]
        var fetchError: Error?

        viewContext.performAndWait {
            do {
                // 1. 모든 채팅방 조회
                let chatRoomFetchRequest = ChatRoomEntity.fetchRequest()
                chatRoomFetchRequest.propertiesToFetch = ["roomId"]
                let chatRooms = try viewContext.fetch(chatRoomFetchRequest)

                // 2. 각 채팅방마다 읽지 않은 메시지 개수 계산
                for chatRoom in chatRooms {
                    guard let roomId = chatRoom.roomId else { continue }

                    let messageFetchRequest = ChatMessageEntity.fetchRequest()

                    if let lastReadMessageId = lastReadMessageIds[roomId] {
                        // lastReadMessageId가 있으면: 해당 메시지 이후 + 상대방이 보낸 + 전송 성공한 메시지
                        // 1) 먼저 lastReadMessageId의 createdAt을 조회
                        let lastMessageFetchRequest = ChatMessageEntity.fetchRequest()
                        lastMessageFetchRequest.predicate = NSPredicate(
                            format: "chatId == %@",
                            lastReadMessageId
                        )
                        lastMessageFetchRequest.fetchLimit = 1

                        if let lastReadMessage = try viewContext.fetch(lastMessageFetchRequest).first,
                           let lastReadDate = lastReadMessage.createdAt {
                            // 2) 해당 날짜 이후의 메시지 개수 계산
                            messageFetchRequest.predicate = NSPredicate(
                                format: "roomId == %@ AND senderId != %@ AND createdAt > %@ AND status == %@",
                                roomId,
                                currentUserId,
                                lastReadDate as NSDate,
                                MessageSendStatus.sent.rawValue
                            )
                        } else {
                            // lastReadMessageId를 찾지 못하면 모든 메시지를 안읽음으로 간주
                            messageFetchRequest.predicate = NSPredicate(
                                format: "roomId == %@ AND senderId != %@ AND status == %@",
                                roomId,
                                currentUserId,
                                MessageSendStatus.sent.rawValue
                            )
                        }
                    } else {
                        // lastReadMessageId가 없으면: 상대방이 보낸 + 전송 성공한 모든 메시지
                        messageFetchRequest.predicate = NSPredicate(
                            format: "roomId == %@ AND senderId != %@ AND status == %@",
                            roomId,
                            currentUserId,
                            MessageSendStatus.sent.rawValue
                        )
                    }

                    // 3. count(for:) 사용
                    do {
                        let count = try viewContext.count(for: messageFetchRequest)
                        unreadCounts[roomId] = count
                    } catch {
                        unreadCounts[roomId] = 0
                    }
                }
            } catch {
                fetchError = error
            }
        }

        if let fetchError = fetchError {
            throw fetchError
        }

        return unreadCounts
    }
}

// MARK: - UPSERT Methods

extension CoreDataManager {

    /// 채팅방 저장 또는 업데이트 (UPSERT)
    /// Unique Constraint 덕분에 roomId가 중복이면 자동으로 업데이트
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    ///   - createdAt: 생성 시간
    ///   - updatedAt: 업데이트 시간
    ///   - context: 사용할 Context (기본값: viewContext)
    /// - Returns: 저장된 ChatRoomEntity
    @discardableResult
    func upsertChatRoom(
        roomId: String,
        createdAt: Date,
        updatedAt: Date,
        context: NSManagedObjectContext? = nil
    ) throws -> ChatRoomEntity {
        let contextToUse = context ?? viewContext

        // 1. 기존 데이터 있는지 확인
        let fetchRequest = ChatRoomEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "roomId == %@", roomId)

        let results = try contextToUse.fetch(fetchRequest)

        // 2. 있으면 업데이트, 없으면 생성
        let chatRoom: ChatRoomEntity
        if let existing = results.first {
            chatRoom = existing
        } else {
            chatRoom = ChatRoomEntity(context: contextToUse)
            chatRoom.roomId = roomId
            chatRoom.createdAt = createdAt
        }

        // 3. 값 업데이트
        chatRoom.updatedAt = updatedAt

        return chatRoom
    }

    /// 메시지 저장 또는 업데이트 (UPSERT)
    /// API와 Socket에서 중복 메시지가 와도 안전하게 처리
    ///
    /// - Parameters:
    ///   - chatId: 메시지 ID
    ///   - roomId: 채팅방 ID
    ///   - content: 메시지 내용
    ///   - senderId: 발신자 ID
    ///   - senderNick: 발신자 닉네임
    ///   - senderProfileImage: 발신자 프로필 이미지
    ///   - createdAt: 생성 시간
    ///   - files: 첨부 파일 (JSON String)
    ///   - status: 전송 상태
    ///   - context: 사용할 Context
    /// - Returns: 저장된 ChatMessageEntity
    @discardableResult
    func upsertChatMessage(
        chatId: String,
        roomId: String,
        content: String?,
        senderId: String,
        senderNick: String,
        senderProfileImage: String?,
        createdAt: Date,
        files: [String]?,
        status: String,
        context: NSManagedObjectContext? = nil
    ) throws -> ChatMessageEntity {
        let contextToUse = context ?? viewContext

        // 1. 기존 메시지 확인
        let fetchRequest = ChatMessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "chatId == %@", chatId)

        let results = try contextToUse.fetch(fetchRequest)

        // 2. UPSERT
        let message: ChatMessageEntity
        if let existing = results.first {
            message = existing
        } else {
            message = ChatMessageEntity(context: contextToUse)
            message.chatId = chatId
            message.roomId = roomId
            message.createdAt = createdAt
        }

        // 3. 값 업데이트
        message.content = content
        message.senderId = senderId
        message.senderNick = senderNick
        message.senderProfileImage = senderProfileImage

        // files 배열 안전하게 저장 (nil 값 및 빈 문자열 필터링)
        // Transformable 속성에 nil이 포함된 배열을 저장하면 크래시 발생
        if let files = files {
            // compactMap으로 nil 제거, filter로 빈 문자열 제거
            let filteredFiles = files.compactMap { $0 }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            message.files = filteredFiles.isEmpty ? nil : (filteredFiles as NSArray)
        } else {
            message.files = nil
        }

        message.status = status

        // 4. ChatRoom relationship 설정 (필수!)
        let chatRoomFetchRequest = ChatRoomEntity.fetchRequest()
        chatRoomFetchRequest.predicate = NSPredicate(format: "roomId == %@", roomId)

        guard let chatRoom = try contextToUse.fetch(chatRoomFetchRequest).first else {
            // ❌ 채팅방을 찾지 못하면 에러 발생 (크래시 방지)
            // 메시지를 저장하기 전에 반드시 ChatRoom이 존재해야 함
            throw CoreDataError.chatRoomNotFound(roomId: roomId)
        }

        // 채팅방을 찾았으면 relationship 설정
        message.chatRoom = chatRoom

        return message
    }
}
