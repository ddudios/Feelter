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
    /// - Parameter context: 저장할 Context (기본값: viewContext)
    /// - Throws: CoreData 저장 에러
    func saveContext(_ context: NSManagedObjectContext? = nil) throws {
        let contextToSave = context ?? viewContext

        // hasChanges: 변경사항이 있을 때만 저장 (성능 최적화)
        guard contextToSave.hasChanges else { return }

        do {
            try contextToSave.save()
        } catch {
            #if DEBUG
            #endif
            throw error
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

        return try viewContext.fetch(fetchRequest)
    }

    /// 특정 채팅방의 메시지 조회
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: ChatMessageEntity 배열 (오래된 순)
    func fetchMessages(for roomId: String) throws -> [ChatMessageEntity] {
        let fetchRequest = ChatMessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "roomId == %@", roomId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        return try viewContext.fetch(fetchRequest)
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

        // files 배열 안전하게 저장 (nil 값 필터링)
        // Transformable 속성에 nil이 포함된 배열을 저장하면 크래시 발생
        if let files = files {
            let filteredFiles = files.filter { !$0.isEmpty }
            message.files = filteredFiles.isEmpty ? nil : (filteredFiles as NSObject)
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
