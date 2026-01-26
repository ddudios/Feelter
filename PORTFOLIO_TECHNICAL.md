# Feelter - iOS 필터 마켓플레이스 및 커뮤니티 (기술 역량 중심)

## 📋 프로젝트 개요

| 항목 | 내용 |
|------|------|
| **프로젝트명** | Feelter (필터 마켓플레이스 & 커뮤니티 앱) |
| **개발 기간** | 2025.01 ~ 진행 중 |
| **개발 인원** | iOS 1명 (본인) |
| **개발 환경** | iOS 15.0+, Swift 5.9, Xcode 15+ |
| **아키텍처** | Clean Architecture + MVVM + Coordinator Pattern |
| **주요 기술** | UIKit, Alamofire, Socket.IO, CoreData, Combine, AVFoundation, Firebase |

---

## 🏗️ 아키텍처 설계

### 1. Clean Architecture 3-Layer 구조

```
Presentation Layer (MVVM + Coordinator)
    ↓ (의존성 역전)
Domain Layer (Entity, Usecase, RepositoryProtocol)
    ↓
Data Layer (Repository, Network, Local)
```

#### 계층별 역할 분리

| 계층 | 역할 | 구현 내용 |
|------|------|-----------|
| **Presentation** | UI 로직 및 화면 전환 | - 22개 ViewController<br>- 14개 ViewModel<br>- 7개 Coordinator<br>- Custom Design System |
| **Domain** | 비즈니스 로직 | - 15개 Usecase<br>- 8개 RepositoryProtocol<br>- Pure Swift Entity (프레임워크 독립적) |
| **Data** | 데이터 소스 추상화 | - 9개 Repository 구현체<br>- REST API (Alamofire)<br>- Socket.IO (실시간 통신)<br>- CoreData (로컬 영속성)<br>- Keychain (보안 저장소) |

#### 핵심 설계 원칙

- **의존성 역전 원칙 (DIP)**: Presentation/Data → Domain 의존 (Protocol 기반)
- **단일 책임 원칙 (SRP)**: 각 계층은 단 하나의 책임만 가짐
- **Protocol-Oriented Programming**: Repository, NetworkManager, Coordinator 모두 프로토콜 기반
- **Dependency Injection**: DIContainer를 통한 의존성 주입

### 2. MVVM + Coordinator 패턴

```swift
// Coordinator: 화면 전환 로직 분리
protocol Coordinator {
    func start()
    func finish()
}

// ViewModel: Input/Output 패턴
protocol ViewModelProtocol {
    associatedtype Input
    associatedtype Output
    func transform(input: Input) -> Output
}
```

- **22개 화면** 모두 Coordinator로 관리 (ViewController는 화면 전환 로직 몰라도 됨)
- **7개 Coordinator** 계층 구조: AppCoordinator → TabBarCoordinator → Feature Coordinators
- **14개 ViewModel** 모두 Input/Output 패턴으로 테스트 가능한 구조

---

## 🔥 핵심 기술 구현 상세

### 1. 실시간 채팅 시스템 (Socket.IO + CoreData + Combine)

#### 1.1 기술 스택

- **Socket.IO**: 실시간 양방향 통신
- **CoreData**: 메시지 영속화 및 오프라인 지원
- **Combine**: 반응형 데이터 스트림
- **AVFoundation**: 동영상 변환 및 썸네일 생성

#### 1.2 채팅 메시지 데이터 흐름 (Hybrid Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│ UI Layer (ChatRoomViewController)                           │
│  ↓ Combine Publisher (observeMessages)                      │
│ ViewModel (ChatRoomViewModel)                               │
│  ↓ Usecase (SendMessageUsecase, FetchChatHistoryUsecase)    │
│ Repository (ChatRepository)                                  │
│  ↓                                                           │
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│ │ REST API     │  │ Socket.IO    │  │ CoreData     │       │
│ │ (전송/조회)   │  │ (실시간 수신) │  │ (로컬 캐시)   │       │
│ └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

#### 1.3 주요 구현 내용

##### (1) Socket.IO 연결 및 실시간 메시지 수신

**파일**: `SocketIOManager.swift:93-143`

```swift
// 특징:
// - Namespace 기반 연결: /chats-{roomId}
// - Authorization 헤더로 JWT 인증
// - 자동 재연결 (무제한 재시도, 5초 간격)
// - PassthroughSubject로 메시지 스트리밍

func connect(to roomId: String) {
    socketManager = SocketManager(socketURL: baseURL, config: [
        .reconnects(true),
        .reconnectAttempts(-1),
        .reconnectWait(5),
        .extraHeaders(["Authorization": token, "SeSACKey": apiKey])
    ])
    socketClient = manager.socket(forNamespace: "/chats-\(roomId)")
    setupEventHandlers()
    socketClient?.connect()
}
```

**핵심 로직**: `SocketIOManager.swift:199-245`
- "chat" 이벤트 리스너 등록
- JSON 직렬화 → DTO 디코딩 → PassthroughSubject로 방출

##### (2) CoreData를 활용한 로컬 우선 전략 (Offline-First)

**파일**: `ChatRepository.swift:120-166`

**전략**:
1. CoreData에서 로컬 데이터 즉시 반환 → UI 빠르게 표시
2. 백그라운드에서 API 호출 (Task로 비동기)
3. API 성공 시 CoreData 업데이트 → Publisher로 UI 자동 갱신
4. 네트워크 실패해도 로컬 데이터는 이미 표시됨 (오프라인 지원)

```swift
func fetchChatRooms() async throws -> [ChatRoom] {
    // 1. 로컬 데이터 먼저 가져오기
    let localChatRooms = try coreDataManager.fetchChatRooms().map { $0.toDomain() }
    if !localChatRooms.isEmpty {
        chatRoomsSubject.send(localChatRooms)  // 즉시 UI 업데이트
    }

    // 2. 백그라운드에서 API 호출
    Task {
        let response = try await networkManager.request(...)
        try saveToCoreData(response)
        await refreshFromCoreData()  // Publisher 업데이트
    }

    // 3. 로컬 데이터 즉시 반환
    return localChatRooms
}
```

##### (3) Optimistic Update 패턴 (낙관적 업데이트)

**파일**: `ChatRepository.swift:267-308`

**전송 흐름**:
1. 로컬에 `.sending` 상태로 임시 메시지 저장 → UI에 즉시 표시
2. API 전송 시도
3. **성공**: 임시 메시지 삭제 → 서버 응답 메시지로 교체
4. **실패**: 임시 메시지를 `.failed` 상태로 변경 → 재전송 버튼 표시

```swift
func sendMessage(...) async throws -> ChatMessage {
    // 1. 임시 메시지 생성 (로컬 ID 부여)
    let localMessage = ChatMessage.createLocal(roomId: roomId, content: content, status: .sending)
    try saveMessageToCoreData(localMessage)
    await refreshMessages(roomId: roomId)  // UI에 즉시 표시

    do {
        // 2. API 전송
        let sentMessage = try await networkManager.request(...)

        // 3. 성공: 임시 메시지 삭제 → 서버 메시지로 교체
        try deleteMessageFromCoreData(chatId: localMessage.chatId)
        try saveMessageToCoreData(sentMessage)
        await refreshMessages(roomId: roomId)
        return sentMessage
    } catch {
        // 4. 실패: .failed 상태로 변경
        let failedMessage = localMessage.with(status: .failed)
        try saveMessageToCoreData(failedMessage)
        await refreshMessages(roomId: roomId)
        throw error
    }
}
```

##### (4) 실패한 메시지 재전송 (FIFO, 24시간 이내)

**파일**: `ChatRepository.swift:582-650`

- **조회 조건**: `.failed` 상태 + 24시간 이내 + 최대 20개
- **정렬**: createdAt 오름차순 (FIFO - 오래된 것부터 재전송)
- **재전송**: 기존 메시지 삭제 → sendMessage() 호출

##### (5) CoreData UPSERT 패턴 (중복 방지)

**파일**: `CoreDataManager.swift:246-310`

- **Merge Policy**: `NSMergeByPropertyObjectTrumpMergePolicy` (새 데이터로 덮어쓰기)
- **Unique Constraint**: `chatId` (중복 메시지 자동 병합)
- **Relationship 자동 설정**: ChatMessageEntity ↔ ChatRoomEntity

```swift
func upsertChatMessage(...) throws -> ChatMessageEntity {
    // 1. 기존 메시지 확인
    let fetchRequest = ChatMessageEntity.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "chatId == %@", chatId)
    let results = try context.fetch(fetchRequest)

    // 2. UPSERT: 있으면 업데이트, 없으면 생성
    let message = results.first ?? ChatMessageEntity(context: context)
    message.chatId = chatId
    message.content = content
    message.files = files  // Transformable (NSArray)

    // 3. Relationship 설정 (필수!)
    guard let chatRoom = try context.fetch(chatRoomFetchRequest).first else {
        throw CoreDataError.chatRoomNotFound(roomId: roomId)
    }
    message.chatRoom = chatRoom

    return message
}
```

##### (6) Socket.IO 메시지 중복 방지 로직

**파일**: `ChatRepository.swift:661-727`

**중복 발생 케이스**:
1. API 응답으로 메시지 저장 → Socket에서 같은 메시지 수신
2. Optimistic Update로 임시 메시지 저장 → Socket에서 서버 메시지 수신

**해결 방법**:
```swift
socketManager.observeMessages().sink { messageDTO in
    Task { @MainActor in
        // 1. CoreData에 이미 존재하는지 확인
        let fetchRequest = ChatMessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "chatId == %@", message.chatId)
        let results = try context.fetch(fetchRequest)
        if !results.isEmpty { return }  // 이미 존재하면 무시

        // 2. .sending 상태의 임시 메시지 삭제 (5초 이내)
        let tempMessages = try context.fetch(...)
        for tempMessage in tempMessages {
            if tempMessage.createdAt >= fiveSecondsAgo {
                context.delete(tempMessage)
            }
        }

        // 3. 새 메시지 저장
        try saveMessageToCoreData(message)
        await refreshMessages(roomId: message.roomId)
    }
}.store(in: &cancellables)
```

##### (7) 파일 전송 (이미지/동영상/PDF)

**파일**: `ChatRepository.swift:327-409`

**동영상 mp4 변환**: `ChatRepository.swift:414-455`
- AVAssetExportSession으로 mov/m4v → mp4 변환
- `AVAssetExportPresetHighestQuality` 사용
- `shouldOptimizeForNetworkUse = true` (스트리밍 최적화)

**동영상 썸네일 자동 생성**: `ChatRepository.swift:457-488`
- AVAssetImageGenerator로 첫 프레임 추출
- JPEG 0.8 품질로 압축

**Multipart/form-data 업로드**:
- 확장자별 다른 Config 시도 (.chat → .chatArray → .chatSingle → .post)
- 서버 응답 400이면 다음 Config로 재시도

##### (8) Combine Publisher로 실시간 UI 업데이트

**파일**: `ChatRepository.swift:234-252`

```swift
// ViewModel에서 사용
repository.observeMessages(roomId: roomId)
    .sink { [weak self] messages in
        self?.updateUI(messages)
    }
    .store(in: &cancellables)
```

- **CurrentValueSubject**: 초기값 보유 (CoreData에서 로드)
- **PassthroughSubject**: Socket 메시지 즉시 전달

#### 1.4 성능 최적화

1. **로컬 우선 전략**: 네트워크 지연 없이 즉시 UI 표시
2. **Lazy Subject 생성**: `observeMessages()` 호출 시에만 Subject 생성
3. **Background Context**: 대량 데이터 저장 시 별도 Context 사용
4. **Merge Policy**: 중복 체크 없이 CoreData가 자동 병합

---

### 2. 네트워크 계층 (Alamofire + async/await + Router Pattern)

#### 2.1 Router Pattern (URLRequestConvertible)

**파일**: `ChatRouter.swift`, `FilterRouter.swift` 등 8개 Router

```swift
enum ChatRouter: URLRequestConvertible {
    case createChatRoom(opponentId: String)
    case fetchChatRooms
    case fetchChatHistory(roomId: String, next: String?)
    case sendMessage(roomId: String, content: String?, files: [String]?)

    var method: HTTPMethod {
        switch self {
        case .createChatRoom, .sendMessage: return .post
        case .fetchChatRooms, .fetchChatHistory: return .get
        }
    }

    var path: String {
        switch self {
        case .createChatRoom: return "/v1/chats"
        case .fetchChatRooms: return "/v1/chats"
        case .fetchChatHistory(let roomId, _): return "/v1/chats/\(roomId)"
        case .sendMessage(let roomId, _, _): return "/v1/chats/\(roomId)"
        }
    }
}
```

**장점**:
- API 엔드포인트를 enum으로 타입 안전하게 관리
- Method, Path, Headers, Parameters를 한 곳에서 관리
- 컴파일 타임에 에러 검출

#### 2.2 async/await 기반 네트워크 통신

**파일**: `NetworkManager.swift:44-60`

```swift
func request<T: Decodable, R: URLRequestConvertible>(_ endpoint: R, type: T.Type) async throws -> T {
    let dataTask = session.request(endpoint)
        .validate()  // 200~299 상태코드 확인
        .serializingDecodable(T.self)  // JSON → DTO 자동 디코딩

    let response = await dataTask.response

    switch response.result {
    case .success(let value):
        return value
    case .failure(let error):
        throw parseError(error, response: response.response, data: response.data)
    }
}
```

**특징**:
- Completion Handler 없이 깔끔한 코드
- try-catch로 에러 처리
- Generic으로 모든 DTO 타입 지원

#### 2.3 AuthenticationInterceptor (토큰 자동 갱신)

**파일**: `AuthenticationInterceptor.swift:24-124`

**동작 흐름**:
```
1. 모든 API 요청 → adapt() 호출 → Keychain에서 AccessToken 가져와서 헤더에 추가
2. 응답이 401/419 (Unauthorized) → retry() 호출
3. RefreshToken으로 새 토큰 발급 (별도 Session 사용 - 순환 의존성 방지)
4. 새 토큰 Keychain 저장
5. 실패했던 모든 요청 자동 재시도 (requestsToRetry 큐)
6. Refresh 실패 시 → 토큰 삭제 + NotificationCenter로 로그아웃 이벤트 발생
```

**핵심 코드**: `AuthenticationInterceptor.swift:42-123`

```swift
func retry(_ request: Request, for session: Session, dueTo error: Error,
           completion: @escaping (RetryResult) -> Void) {
    guard let response = request.task?.response as? HTTPURLResponse,
          response.statusCode == 401 || response.statusCode == 419 else {
        completion(.doNotRetryWithError(error))
        return
    }

    // 로그아웃 요청은 재시도 안 함
    if request.request?.url?.absoluteString.contains("logout") == true {
        completion(.doNotRetry)
        return
    }

    // 이미 토큰 갱신 중이면 큐에 추가
    requestsToRetry.append(completion)
    guard !isRefreshing else { return }

    isRefreshing = true

    Task {
        do {
            // RefreshToken으로 새 토큰 발급
            let newToken = try await repository.refreshToken(...)
            KeychainManager.shared.save(token: newToken.accessToken, account: "accessToken")
            KeychainManager.shared.save(token: newToken.refreshToken, account: "refreshToken")

            // 대기 중인 모든 요청 재시도
            await MainActor.run {
                self.isRefreshing = false
                self.requestsToRetry.forEach { $0(.retry) }
                self.requestsToRetry.removeAll()
            }
        } catch {
            // Refresh 실패 → 로그아웃
            await MainActor.run {
                KeychainManager.shared.delete(account: "accessToken")
                KeychainManager.shared.delete(account: "refreshToken")
                NotificationCenter.default.post(name: .unauthorizedError, object: nil)
                self.isRefreshing = false
                self.requestsToRetry.forEach { $0(.doNotRetry) }
                self.requestsToRetry.removeAll()
            }
        }
    }
}
```

**핵심 기술**:
- **큐잉 메커니즘**: 여러 API가 동시에 401을 받아도 Refresh는 1번만 호출
- **순환 의존성 방지**: Refresh 요청은 Interceptor 없는 별도 Session 사용
- **메인 스레드 보장**: UI 업데이트는 `@MainActor.run`으로 안전하게 처리

#### 2.4 파일 업로드 시스템 (Config 기반)

**파일**: `NetworkManager.swift:139-246`

**FileUploadConfig 시스템**:
```swift
enum FileUploadConfig {
    case profile      // jpg, png, jpeg / 5MB / 1개 / "profile"
    case filter       // jpg, png, jpeg / 2MB / 2개 / "files"
    case chat         // jpg, png, jpeg, gif, pdf, mp3, mp4, m4a, mov / 50MB / 5개 / "files"
    case post         // jpg, png, jpeg, gif, mp4, mov, m4v / 50MB / 5개 / "files"

    var allowedExtensions: [String]
    var maxFileSize: Int
    var maxFileCount: Int
    var parameterName: String

    func validate(_ dataList: [Data]) throws {
        guard dataList.count <= maxFileCount else {
            throw FileUploadError.tooManyFiles
        }
        for data in dataList {
            guard data.count <= maxFileSize else {
                throw FileUploadError.fileTooLarge
            }
        }
    }

    static func mimeType(for extension: String) -> String {
        switch extension {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
}
```

**Multipart/form-data 업로드**:
```swift
func uploadFiles(_ dataList: [Data], fileExtensions: [String],
                 config: FileUploadConfig, endpoint: URLRequestConvertible) async throws -> [String] {
    try config.validate(dataList)

    return try await withCheckedThrowingContinuation { continuation in
        session.upload(
            multipartFormData: { multipartFormData in
                for (index, data) in dataList.enumerated() {
                    let fileExtension = fileExtensions[index]
                    let mimeType = FileUploadConfig.mimeType(for: fileExtension)
                    let fileName = "\(config.parameterName)_\(index)_\(timestamp).\(fileExtension)"

                    multipartFormData.append(data, withName: config.parameterName,
                                           fileName: fileName, mimeType: mimeType)
                }
            },
            with: endpoint
        )
        .validate()
        .responseDecodable(of: FileUploadResponseDTO.self) { response in
            switch response.result {
            case .success(let value):
                continuation.resume(returning: value.files)
            case .failure(let error):
                continuation.resume(throwing: self.parseError(error, ...))
            }
        }
    }
}
```

**핵심 기술**:
- **Config 기반 검증**: 확장자, 파일 크기, 개수 자동 검증
- **확장자별 MIME Type 자동 결정**: jpg → image/jpeg, mp4 → video/mp4
- **async/await 통합**: `withCheckedThrowingContinuation`으로 Alamofire 콜백 → async/await 변환

#### 2.5 DTO to Domain Entity Mapping

**파일**: `PostDTO+Mapping.swift`, `ChatMessageResponseDTO+Mapping.swift` 등

```swift
// DTO (Data Layer)
struct ChatMessageResponseDTO: Decodable {
    let chatId: String
    let roomId: String
    let content: String?
    let createdAt: String  // ISO8601 문자열
    let sender: SenderDTO
    let files: [String]?

    // DTO → Domain Entity 변환
    func toDomain() -> ChatMessage {
        return ChatMessage(
            chatId: chatId,
            roomId: roomId,
            content: content,
            createdAt: ISO8601DateParser.parse(createdAt) ?? Date(),  // 문자열 → Date
            senderId: sender.userId,
            senderNick: sender.nick,
            senderProfileImage: sender.profileImage,
            files: files ?? [],
            status: .sent
        )
    }
}

// Entity (Domain Layer - Pure Swift)
struct ChatMessage {
    let chatId: String
    let roomId: String
    let content: String?
    let createdAt: Date  // Date 타입 (프레임워크 독립적)
    let senderId: String
    let senderNick: String
    let senderProfileImage: String?
    let files: [String]
    let status: MessageSendStatus
}
```

**핵심**:
- **Domain Layer는 Pure Swift**: Decodable 프로토콜 없음 (프레임워크 독립적)
- **DTO는 Data Layer에서만 사용**: 네트워크 응답 구조에 종속
- **Mapping 로직 분리**: `+Mapping.swift` 파일로 확장

---

### 3. CoreData 영속성 관리

#### 3.1 CoreData Stack 구성

**파일**: `CoreDataManager.swift:35-78`

```swift
class CoreDataManager {
    static let shared = CoreDataManager()

    private let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    init(modelName: String = "FeelterChat") {
        container = NSPersistentContainer(name: modelName)

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("CoreData Store 로드 실패: \(error)")
            }
        }

        // Merge Policy 설정 (중복 처리 전략)
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
```

#### 3.2 Entity 모델

**파일**: `FeelterChat.xcdatamodeld`

**ChatRoomEntity**:
- roomId (Unique Constraint)
- createdAt, updatedAt
- opponentUserId, opponentNick, opponentProfileImage
- lastReadAt (로컬에서만 관리)
- messages (Relationship - One to Many)

**ChatMessageEntity**:
- chatId (Unique Constraint)
- roomId
- content, senderId, senderNick, senderProfileImage
- createdAt
- files (Transformable - [String]을 NSArray로 저장)
- status (sending, sent, failed)
- chatRoom (Relationship - Many to One)

#### 3.3 Entity to Domain Mapping

**파일**: `ChatMessageEntity+Mapping.swift`, `ChatRoomEntity+Mapping.swift`

```swift
extension ChatMessageEntity {
    func toDomain() -> ChatMessage {
        return ChatMessage(
            chatId: chatId ?? "",
            roomId: roomId ?? "",
            content: content,
            createdAt: createdAt ?? Date(),
            senderId: senderId ?? "",
            senderNick: senderNick ?? "",
            senderProfileImage: senderProfileImage,
            files: (files as? [String]) ?? [],  // NSArray → [String]
            status: MessageSendStatus(rawValue: status ?? "sent") ?? .sent
        )
    }
}
```

#### 3.4 UPSERT 메서드

**파일**: `CoreDataManager.swift:189-311`

**채팅방 UPSERT**:
```swift
@discardableResult
func upsertChatRoom(roomId: String, createdAt: Date, updatedAt: Date) throws -> ChatRoomEntity {
    let fetchRequest = ChatRoomEntity.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "roomId == %@", roomId)
    let results = try viewContext.fetch(fetchRequest)

    let chatRoom: ChatRoomEntity
    if let existing = results.first {
        chatRoom = existing  // 업데이트
    } else {
        chatRoom = ChatRoomEntity(context: viewContext)  // 생성
        chatRoom.roomId = roomId
        chatRoom.createdAt = createdAt
    }

    chatRoom.updatedAt = updatedAt
    return chatRoom
}
```

**메시지 UPSERT**:
- **Relationship 자동 설정**: ChatRoom이 없으면 에러 발생 (크래시 방지)
- **files 배열 안전 저장**: nil 값 및 빈 문자열 필터링

#### 3.5 로컬 데이터 조회

**채팅방 목록**: `CoreDataManager.swift:167-172`
```swift
func fetchChatRooms() throws -> [ChatRoomEntity] {
    let fetchRequest = ChatRoomEntity.fetchRequest()
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
    return try viewContext.fetch(fetchRequest)
}
```

**메시지 목록**: `CoreDataManager.swift:178-184`
```swift
func fetchMessages(for roomId: String) throws -> [ChatMessageEntity] {
    let fetchRequest = ChatMessageEntity.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "roomId == %@", roomId)
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
    return try viewContext.fetch(fetchRequest)
}
```

---

### 4. 푸시 알림 및 Deep Link

#### 4.1 Firebase Cloud Messaging (FCM) 통합

**파일**: `AppDelegate.swift:32-40`

```swift
private func setupNotification(_ application: UIApplication) {
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self

    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { _, _ in }

    application.registerForRemoteNotifications()
}
```

#### 4.2 포그라운드 알림 제어

**파일**: `AppDelegate.swift:57-73`

**로직**:
1. 푸시 알림 수신 시 `NotificationPayload` 파싱
2. 현재 화면이 해당 채팅방인지 확인
3. 같은 채팅방이면 알림 생략, 다른 화면이면 알림 표시

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           willPresent notification: UNNotification,
                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo

    guard let payload = NotificationPayload.from(userInfo: userInfo),
          let pushRoomId = payload.roomId else {
        completionHandler([.banner, .list, .sound, .badge])
        return
    }

    // 현재 화면 확인
    if let currentChatRoomId = getCurrentVisibleChatRoomId(),
       currentChatRoomId == pushRoomId {
        completionHandler([])  // 동일 채팅방이면 알림 생략
    } else {
        completionHandler([.banner, .list, .sound, .badge])
    }
}
```

#### 4.3 Deep Link 라우팅

**파일**: `AppDelegate.swift:76-84`, `NotificationDeepLinkRouter.swift`

**흐름**:
1. 알림 클릭 → `didReceive response` 호출
2. `NotificationDeepLinkRouter`로 roomId 추출
3. SceneDelegate → AppCoordinator로 라우팅 명령 전달
4. ChatCoordinator가 해당 채팅방 화면 push

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           didReceive response: UNNotificationResponse,
                           withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo

    if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
        NotificationDeepLinkRouter.routeToChatRoom(from: userInfo, sceneDelegate: sceneDelegate)
    }
    completionHandler()
}
```

#### 4.4 FCM 토큰 서버 동기화

**파일**: `AppDelegate.swift:107-126`

```swift
func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let token = fcmToken else { return }

    Task {
        await updateDeviceTokenToServer(token)
    }
}

private func updateDeviceTokenToServer(_ token: String) async {
    guard let accessToken = KeychainManager.shared.read(account: "accessToken"),
          !accessToken.isEmpty else { return }

    do {
        try await networkManager.requestWithEmptyResponse(
            UserRouter.updateDeviceToken(body: .init(deviceToken: token))
        )
    } catch {
        print("Token update failed: \(error)")
    }
}
```

---

### 5. AVFoundation을 활용한 동영상 처리

#### 5.1 동영상 mp4 변환

**파일**: `ChatRepository.swift:414-455`, `CommunityRepository.swift:148-189`

**사용 케이스**:
- 채팅에서 mov/m4v 파일 전송 시
- 커뮤니티 게시글에 동영상 업로드 시

```swift
private func convertVideoToMP4(from videoData: Data) async throws -> Data {
    // 1. Data를 임시 파일로 저장 (AVAsset은 URL 필요)
    let tempDirectory = FileManager.default.temporaryDirectory
    let inputURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mov")
    let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mp4")

    try videoData.write(to: inputURL)

    defer {
        try? FileManager.default.removeItem(at: inputURL)
        try? FileManager.default.removeItem(at: outputURL)
    }

    // 2. AVAsset으로 동영상 로드
    let asset = AVAsset(url: inputURL)

    // 3. Export Session 생성
    guard let exportSession = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPresetHighestQuality
    ) else {
        throw FileUploadError.noFiles
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true  // 스트리밍 최적화

    // 4. 변환 시작 (async/await)
    await exportSession.export()

    guard exportSession.status == .completed else {
        throw FileUploadError.noFiles
    }

    // 5. mp4 파일을 Data로 읽기
    let mp4Data = try Data(contentsOf: outputURL)
    return mp4Data
}
```

**핵심 기술**:
- `AVAssetExportPresetHighestQuality`: 최고 품질 유지
- `shouldOptimizeForNetworkUse = true`: Fast Start 활성화 (moov atom을 파일 앞으로 이동)
- async/await로 변환: `await exportSession.export()`

#### 5.2 동영상 썸네일 생성

**파일**: `ChatRepository.swift:457-488`

```swift
private func generateVideoThumbnail(from videoData: Data) throws -> Data {
    let tempDirectory = FileManager.default.temporaryDirectory
    let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mov")

    try videoData.write(to: tempFileURL)

    defer {
        try? FileManager.default.removeItem(at: tempFileURL)
    }

    let asset = AVAsset(url: tempFileURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true  // 회전 정보 적용

    // 첫 프레임 추출 (0초)
    let time = CMTime(seconds: 0, preferredTimescale: 600)
    let imageRef = try generator.copyCGImage(at: time, actualTime: nil)
    let thumbnailImage = UIImage(cgImage: imageRef)

    // JPEG 0.8 품질로 압축
    guard let jpegData = thumbnailImage.jpegData(compressionQuality: 0.8) else {
        throw FileUploadError.noFiles
    }

    return jpegData
}
```

#### 5.3 HLS 스트리밍 재생

**파일**: `VideoDetailViewController.swift`

**WebVTT 자막 파싱**: `VideoRepository.swift:39-45`
```swift
func fetchSubtitle(url: String) async throws -> [SubtitleItem] {
    let webvttContent = try await networkManager.requestString(VideoRouter.subtitle(url: url))
    return WebVTTParser.parse(webvttContent)
}
```

---

### 6. 결제 시스템 (아임포트)

#### 6.1 결제 상태 관리 (앱 종료 대응)

**파일**: `PaymentStateManager.swift`

**문제**: 아임포트 결제 중 앱이 종료되면 결제 완료 여부 확인 불가

**해결**: UserDefaults에 PendingPayment 저장 → 앱 재실행 시 복구

```swift
struct PendingPayment: Codable {
    let filterId: String
    let orderCode: String
    let totalPrice: Int
    let createdAt: Date

    var isExpired: Bool {
        let expirationInterval: TimeInterval = 24 * 60 * 60  // 24시간
        return Date().timeIntervalSince(createdAt) > expirationInterval
    }
}

func savePendingPayment(filterId: String, orderCode: String, totalPrice: Int) {
    let payment = PendingPayment(...)
    let data = try JSONEncoder().encode(payment)
    UserDefaults.standard.set(data, forKey: Keys.pendingPayment)
}

func getPendingPayment() -> PendingPayment? {
    guard let data = UserDefaults.standard.data(forKey: Keys.pendingPayment) else {
        return nil
    }

    let payment = try JSONDecoder().decode(PendingPayment.self, from: data)

    if payment.isExpired {
        clearPendingPayment()
        return nil
    }

    return payment
}
```

#### 6.2 결제 흐름

1. 주문 생성 (POST /v1/payments/order)
2. PendingPayment 저장
3. 아임포트 SDK 호출
4. 결제 완료 콜백
5. 결제 검증 (POST /v1/payments/validation)
6. PendingPayment 삭제

---

### 7. Keychain을 통한 보안 토큰 저장

**파일**: `KeychainManager.swift`

```swift
final class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.wkdtnwl.Feelter"

    func save(token: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: token.data(using: .utf8)!
        ]

        SecItemDelete(query as CFDictionary)  // 기존 항목 삭제
        SecItemAdd(query as CFDictionary, nil)  // 새 항목 추가
    }

    func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

**저장 항목**:
- `accessToken`: API 인증 토큰
- `refreshToken`: 토큰 갱신용
- `userId`: 현재 로그인 사용자 ID

---

### 8. Coordinator Pattern으로 화면 전환 관리

#### 8.1 Coordinator 프로토콜

**파일**: `Coordinator.swift`

```swift
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get set }
    var childCoordinators: [Coordinator] { get set }
    var finishDelegate: CoordinatorFinishDelegate? { get set }
    var type: CoordinatorType { get }

    func start()
    func finish()
}

protocol CoordinatorFinishDelegate: AnyObject {
    func coordinatorDidFinish(childCoordinator: Coordinator)
}
```

#### 8.2 Coordinator 계층 구조

```
AppCoordinator
  ├─ AuthCoordinator (로그인/회원가입)
  └─ TabBarCoordinator
       ├─ HomeCoordinator (홈 화면)
       ├─ FeedCoordinator (동영상 피드)
       ├─ SearchCoordinator (커뮤니티)
       ├─ ChatCoordinator (채팅)
       └─ ProfileCoordinator (프로필)
```

#### 8.3 화면 전환 예시

**파일**: `ChatCoordinator.swift`

```swift
final class ChatCoordinator: Coordinator {
    var navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    var finishDelegate: CoordinatorFinishDelegate?
    var type: CoordinatorType = .chat

    func start() {
        let viewModel = ChatRoomListViewModel(...)
        let viewController = ChatRoomListViewController(viewModel: viewModel)
        viewController.coordinator = self
        navigationController.pushViewController(viewController, animated: true)
    }

    func showChatRoom(roomId: String) {
        let viewModel = ChatRoomViewModel(roomId: roomId, ...)
        let viewController = ChatRoomViewController(viewModel: viewModel)
        viewController.coordinator = self
        navigationController.pushViewController(viewController, animated: true)
    }

    func finish() {
        finishDelegate?.coordinatorDidFinish(childCoordinator: self)
    }
}
```

**장점**:
- ViewController는 화면 전환 로직 몰라도 됨 (`coordinator?.showChatRoom(...)` 호출만)
- 화면 전환 로직을 한 곳에서 관리 (재사용 가능)
- Child Coordinator로 메모리 관리 자동화

---

### 9. 위치 기반 게시글 조회 (CoreLocation)

**파일**: `CommunityRepository.swift:20-45`

```swift
func fetchGeolocationPosts(
    category: String?,
    longitude: Double?,
    latitude: Double?,
    maxDistance: Int?,  // 미터 단위
    limit: Int?,
    next: String?,
    orderBy: PostSortType
) async throws -> (posts: [PostSummary], nextCursor: String?) {
    let requestDTO = PostListRequestDTO(
        category: category,
        longitude: longitude.map { String(format: "%.6f", $0) },
        latitude: latitude.map { String(format: "%.6f", $0) },
        maxDistance: maxDistance.map { String($0) },
        limit: limit,
        next: next,
        orderBy: orderBy
    )

    let response = try await networkManager.request(
        PostRouter.geolocationPosts(query: requestDTO),
        type: PostListResponseDTO.self
    )

    return response.toDomain()
}
```

---

### 10. 무한 스크롤 (Cursor Pagination)

**구현 방식**:
- 서버가 `nextCursor` 반환
- ViewModel에서 `nextCursor` 저장
- 마지막 셀 도달 시 `next=nextCursor`로 다음 페이지 요청

**예시**: `FilterRepository.swift:18-40`
```swift
func fetchFilterList(
    category: FilterCategory?,
    orderBy: FilterSortType,
    next: String?,  // 다음 페이지 커서
    limit: String?
) async throws -> FilterList {
    let response = try await networkManager.request(...)

    return FilterList(
        filters: response.data.map { $0.toSummaryDomain() },
        nextCursor: response.nextCursor  // 다음 페이지 커서
    )
}
```

---

### 11. 이미지 캐싱 (Kingfisher + Custom Modifier)

**파일**: `AppDelegate.swift:27`

```swift
KingfisherManager.shared.defaultOptions = [.requestModifier(AuthHeaderModifier())]
```

**파일**: `AuthHeaderModifier.swift`

```swift
struct AuthHeaderModifier: ImageDownloadRequestModifier {
    func modified(for request: URLRequest) -> URLRequest? {
        var modifiedRequest = request

        if let accessToken = KeychainManager.shared.read(account: "accessToken") {
            modifiedRequest.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }
        modifiedRequest.setValue(Config.apiKey, forHTTPHeaderField: "SeSACKey")

        return modifiedRequest
    }
}
```

**효과**:
- 모든 이미지 요청에 자동으로 인증 헤더 추가
- Kingfisher가 자동으로 메모리/디스크 캐싱

---

### 12. Dependency Injection Container

**파일**: `DIContainer.swift`, `AppDI.swift`

```swift
final class DIContainer {
    static let shared = DIContainer()

    private var dependencies: [String: Any] = [:]

    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        dependencies[key] = instance
    }

    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return dependencies[key] as? T
    }
}

// 사용 예시
extension DIContainer {
    func registerRepositories() {
        register(ChatRepositoryProtocol.self, instance: ChatRepository())
        register(FilterRepositoryProtocol.self, instance: FilterRepository())
        // ...
    }
}
```

---

## 🧪 테스트 가능한 설계

### 1. Protocol-Oriented Programming

모든 핵심 컴포넌트를 프로토콜로 추상화:
- `NetworkManagerProtocol`: 네트워크 요청 로직
- `ChatRepositoryProtocol`: 채팅 데이터 관리
- `SocketIOManager`: Mock으로 교체 가능

### 2. Pure Domain Entity

Domain Layer는 프레임워크 의존성 없음:
```swift
// ✅ Good: Pure Swift
struct ChatMessage {
    let chatId: String
    let content: String?
    let createdAt: Date
}

// ❌ Bad: UIKit 의존
struct ChatMessage {
    let chatId: String
    let content: NSAttributedString  // UIKit 의존
}
```

### 3. ViewModel Input/Output 패턴

```swift
protocol ViewModelProtocol {
    associatedtype Input
    associatedtype Output

    func transform(input: Input) -> Output
}

final class ChatRoomViewModel: ViewModelProtocol {
    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let sendMessageTap: AnyPublisher<String, Never>
    }

    struct Output {
        let messages: AnyPublisher<[ChatMessage], Never>
        let sendResult: AnyPublisher<Result<Void, Error>, Never>
    }

    func transform(input: Input) -> Output {
        // 테스트 가능한 순수 함수형 로직
    }
}
```

---

## 📊 성능 최적화

### 1. 네트워크

- **Cursor Pagination**: 무한 스크롤로 메모리 효율성
- **이미지 캐싱**: Kingfisher 메모리/디스크 캐싱
- **파일 압축**: JPEG 0.8 품질, 동영상 스트리밍 최적화

### 2. CoreData

- **Lazy Fetching**: 필요한 데이터만 조회
- **Batch Operations**: NSBatchDeleteRequest로 대량 삭제
- **Merge Policy**: 중복 체크 없이 자동 병합

### 3. UI

- **CollectionView CompositionalLayout**: 복잡한 레이아웃 성능 향상
- **Cell Reuse**: 메모리 효율적인 셀 재사용
- **비동기 이미지 로딩**: 메인 스레드 블로킹 방지

---

## 🔐 보안

1. **Keychain**: 토큰을 안전하게 암호화하여 저장
2. **HTTPS**: 모든 네트워크 통신 암호화
3. **토큰 자동 갱신**: 만료된 토큰 자동 갱신으로 세션 유지
4. **민감 정보 분리**: Config.swift + Info.plist로 API Key 관리

---

## 📈 주요 성과

### 정량적 성과

| 항목 | 수치 |
|------|------|
| **전체 코드 라인** | ~15,000+ lines |
| **화면 개수** | 22개 |
| **Repository** | 9개 |
| **Usecase** | 15개 |
| **Router (API 엔드포인트)** | 8개 (50+ 엔드포인트) |
| **CoreData Entity** | 2개 (ChatRoom, ChatMessage) |

### 정성적 성과

1. **확장 가능한 아키텍처**: Clean Architecture로 유지보수성 극대화
2. **오프라인 지원**: CoreData 기반 로컬 우선 전략
3. **실시간 통신**: Socket.IO + Combine으로 반응형 UI
4. **안정적인 인증**: Interceptor 기반 토큰 자동 갱신
5. **파일 처리**: AVFoundation으로 동영상 변환 및 썸네일 생성

---

## 🛠️ 기술 스택 상세

### Core

| 기술 | 용도 | 주요 구현 |
|------|------|-----------|
| **UIKit** | UI 프레임워크 | 모든 화면 코드 기반 구현 |
| **Swift 5.9** | 언어 | async/await, Concurrency |
| **Combine** | 반응형 프로그래밍 | Publisher로 실시간 데이터 스트림 |

### Network

| 기술 | 용도 | 주요 구현 |
|------|------|-----------|
| **Alamofire** | HTTP 네트워크 | REST API, 파일 업로드, Interceptor |
| **Socket.IO** | 실시간 통신 | 채팅 메시지 실시간 수신 |

### Persistence

| 기술 | 용도 | 주요 구현 |
|------|------|-----------|
| **CoreData** | 로컬 DB | 채팅 메시지 영속화, UPSERT 패턴 |
| **Keychain** | 보안 저장소 | 토큰 암호화 저장 |
| **UserDefaults** | 간단한 저장소 | 결제 상태 임시 저장 |

### Media

| 기술 | 용도 | 주요 구현 |
|------|------|-----------|
| **AVFoundation** | 미디어 처리 | 동영상 mp4 변환, 썸네일 생성, HLS 재생 |
| **Kingfisher** | 이미지 캐싱 | 메모리/디스크 캐싱, 커스텀 Modifier |

### Authentication

| 기술 | 용도 | 주요 구현 |
|------|------|-----------|
| **Firebase (FCM)** | 푸시 알림 | APNs 통합, 토큰 관리 |
| **KakaoSDK** | 소셜 로그인 | Kakao 로그인 |
| **Apple Sign In** | 소셜 로그인 | Apple 로그인 |

### Payment

| 기술 | 용도 | 주요 구현 |
|------|------|-----------|
| **아임포트** | 결제 | 필터 구매 결제 및 검증 |

---

## 💡 문제 해결 경험

### 1. 채팅 메시지 중복 문제

**문제**: API 응답과 Socket 메시지가 동시에 도착하여 중복 저장

**해결**:
- CoreData Unique Constraint (chatId)
- UPSERT 패턴으로 자동 병합
- Socket 리스너에서 중복 체크 로직 추가

### 2. 토큰 만료 시 여러 API 동시 실패

**문제**: 여러 API가 동시에 401 에러 → Refresh Token API가 중복 호출

**해결**:
- Interceptor에서 큐잉 메커니즘 구현
- `isRefreshing` 플래그로 중복 호출 방지
- 실패한 요청들을 `requestsToRetry` 배열에 저장 → Refresh 성공 후 일괄 재시도

### 3. 앱 종료 시 결제 상태 손실

**문제**: 아임포트 결제 중 앱 종료 → 결제 완료 여부 확인 불가

**해결**:
- UserDefaults에 PendingPayment 저장
- 앱 재실행 시 복구 로직 실행
- 24시간 자동 만료 처리

### 4. CoreData Relationship 크래시

**문제**: ChatMessage 저장 시 ChatRoom이 없으면 크래시

**해결**:
- 메시지 저장 전 ChatRoom 존재 여부 확인
- 없으면 최소한의 정보로 ChatRoom 먼저 생성
- `saveChatRoomContext()` 호출하여 Relationship 설정 보장

### 5. 동영상 파일 크기 및 호환성

**문제**: mov/m4v 파일은 서버에서 지원 안 함 + 파일 크기가 큼

**해결**:
- AVAssetExportSession으로 mp4 변환
- `shouldOptimizeForNetworkUse = true`로 스트리밍 최적화
- 변환 실패 시 에러 처리 및 사용자에게 알림

---

## 📝 회고

### Keep (유지할 점)

1. **Clean Architecture**: 계층 분리로 테스트 가능하고 유지보수하기 쉬운 코드
2. **Protocol-Oriented Programming**: Mock 객체로 테스트 가능
3. **async/await**: 깔끔한 비동기 코드

### Problem (개선할 점)

1. **테스트 코드 부재**: Unit Test 작성 필요
2. **에러 처리 개선**: 사용자 친화적인 에러 메시지 필요
3. **로깅 시스템**: 디버깅을 위한 체계적인 로깅 필요

### Try (시도할 점)

1. **TDD 도입**: 핵심 로직부터 테스트 작성
2. **SwiftUI 마이그레이션**: 일부 화면부터 SwiftUI로 전환
3. **CI/CD 구축**: GitHub Actions로 자동 빌드/배포

---

## 📞 연락처

- GitHub: [링크]
- Email: [이메일]
- Blog: [블로그]
