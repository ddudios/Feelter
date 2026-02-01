# FilterHub - 실시간 채팅 기능 포트폴리오

## 📱 구현 기능 요약

Socket.IO 기반 실시간 1:1 채팅 시스템을 Clean Architecture로 구현했습니다. Optimistic Update와 메시지 대기열을 통해 빠른 사용자 경험을 제공하며, 네트워크 불안정 상황에서도 안정적으로 동작하도록 설계했습니다.

### 핵심 기능
- Socket.IO 기반 실시간 메시지 송수신
- Optimistic Update를 통한 즉각적인 UI 반영
- 실패한 메시지 자동/수동 재전송 (Actor 기반 대기열)
- CoreData 기반 오프라인 지원 (로컬 우선 전략)
- 멀티미디어 파일 업로드 (이미지, 동영상, 문서)
- 읽지 않은 메시지 배지 및 실시간 동기화
- 네트워크 재연결 시 자동 복구

---

## 🛠 기술 스택 및 적용 이유

### Architecture & Design Pattern
- **Clean Architecture (Domain/Data/Presentation)**: 비즈니스 로직과 UI를 완전히 분리하여 테스트 가능성과 유지보수성 확보
- **MVVM + Coordinator**: ViewModel의 역할을 명확히 하고, 화면 전환 로직을 분리
- **Repository Pattern**: 다양한 데이터 소스(API, CoreData, Socket.IO)를 단일 인터페이스로 추상화

### Reactive Programming
- **Combine**: Input/Output 패턴으로 명확한 데이터 흐름 정의, Publisher를 통한 실시간 UI 업데이트
- **CurrentValueSubject/PassthroughSubject**: 채팅방 목록, 메시지 목록의 실시간 변경 감지

### Concurrency
- **Swift Concurrency (async/await)**: 네트워크 요청, CoreData 작업의 비동기 처리
- **Actor (MessageQueueManager)**: 메시지 전송 대기열의 동시성 안전 보장

### Local Storage & Real-time
- **CoreData**: 오프라인 지원, 로컬 캐싱, UPSERT를 통한 데이터 정합성 보장
- **Socket.IO**: 실시간 메시지 수신 (각 채팅방별 namespace 분리)
- **NWPathMonitor**: 네트워크 상태 감지 및 재연결 이벤트 처리

### Network
- **Alamofire**: REST API 통신, Router 패턴, multipart/form-data 파일 업로드
- **AVFoundation**: 동영상 포맷 변환 (mov → mp4), 썸네일 생성

### 기술 선택 이유 (신입 개발자 관점)

**1. Clean Architecture 선택 이유**
- 초기에는 MVVM만 사용했으나, UseCase가 ViewModel에 섞이면서 복잡도가 증가
- Domain Layer 분리로 비즈니스 로직을 독립적으로 테스트 가능하게 변경
- Repository Protocol로 Mock 객체 생성이 쉬워져 Unit Test 작성이 용이해짐

**2. Combine 선택 이유**
- RxSwift를 고려했으나, Apple 공식 프레임워크이고 추가 의존성이 없어 Combine 선택
- Publisher 체인으로 채팅방 목록/메시지 목록의 실시간 업데이트를 선언적으로 구현
- `observeMessages()` Publisher가 CoreData 변경을 자동으로 감지하여 UI 업데이트

**3. Actor 선택 이유**
- 메시지 전송 대기열(Queue)에서 Data Race 문제 발생 우려
- DispatchQueue 대신 Actor를 사용하여 Swift 컴파일러 수준에서 동시성 안전 보장
- async/await와 자연스럽게 통합되어 코드 가독성 향상

**4. Socket.IO 선택 이유**
- WebSocket 대신 Socket.IO를 사용한 이유: 자동 재연결, Fallback 지원
- 각 채팅방마다 별도 namespace(`/chats-{roomId}`)로 분리하여 메시지 필터링 불필요
- Combine Publisher로 래핑하여 기존 아키텍처와 일관성 유지

**5. CoreData 선택 이유**
- Realm을 고려했으나, Apple 공식 프레임워크이고 iCloud 동기화 확장 가능성 고려
- Fetch Request를 통한 복잡한 쿼리 (실패한 메시지 24시간 이내, 최근 20개 등)
- Relationship을 통해 ChatRoom ↔ ChatMessage 관계를 명확히 정의

---

## 💡 주요 구현 내용

### 1. Clean Architecture 3-Layer 구조

**Domain Layer**
```swift
// Entity: 비즈니스 모델 (DTO/Entity와 완전히 분리)
struct ChatMessage: Equatable, Hashable, Identifiable {
    let chatId: String
    let roomId: String
    let content: String?
    let senderId: String
    let createdAt: Date
    let files: [String]
    var status: MessageSendStatus  // 로컬 전송 상태 관리
}

// UseCase: 비즈니스 로직 캡슐화
final class SendMessageUsecase {
    func execute(roomId: String, content: String, files: [String]) async throws -> ChatMessage {
        // 1. 입력 검증 (빈 메시지, 길이 제한)
        // 2. Repository 호출
        // 3. 에러 변환 (NetworkError → SendMessageError)
    }
}

// Repository Protocol: 데이터 소스 추상화
protocol ChatRepositoryProtocol {
    func sendMessage(roomId: String, content: String?, files: [String]) async throws -> ChatMessage
    func observeMessages(roomId: String) -> AnyPublisher<[ChatMessage], Never>
    func connectSocket(roomId: String)
}
```

**Data Layer**
```swift
// Repository: API + CoreData + Socket.IO 통합
final class ChatRepository: ChatRepositoryProtocol {
    private let networkManager: NetworkManagerProtocol
    private let coreDataManager: CoreDataManager
    private let socketManager: SocketIOManager

    // 실시간 메시지 Subject
    private var messagesSubjects: [String: CurrentValueSubject<[ChatMessage], Never>] = [:]

    func observeMessages(roomId: String) -> AnyPublisher<[ChatMessage], Never> {
        // CoreData Fetch → Subject 생성 → Publisher 반환
    }
}
```

**Presentation Layer**
```swift
// ViewModel: Input/Output 패턴 + Combine
final class ChatRoomViewModel {
    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let sendButtonTapped: AnyPublisher<Void, Never>
        let messageText: AnyPublisher<String, Never>
    }

    struct Output {
        let messages: AnyPublisher<[ChatMessage], Never>
        let isLoading: AnyPublisher<Bool, Never>
        let error: AnyPublisher<String?, Never>
    }
}
```

**기술적 의사결정**
- Domain Entity와 DTO를 완전히 분리하여 서버 스펙 변경 시 Domain Layer 영향 최소화
- Repository Protocol로 추상화하여 Test 시 Mock Repository 주입 가능
- UseCase에서 입력 검증, 에러 변환을 처리하여 ViewModel의 복잡도 감소

---

### 2. Socket.IO 실시간 채팅

**Socket.IO 연결 구조**
```swift
final class SocketIOManager {
    private var socketManager: SocketManager?
    private let messageSubject = PassthroughSubject<ChatMessageResponseDTO, Never>()

    func connect(to roomId: String) {
        // 1. 토큰 확인 (Keychain에서 accessToken 조회)
        guard let token = getAccessToken() else {
            errorSubject.send(.noToken)
            return
        }

        // 2. Socket.IO Manager 생성
        // Namespace: "/chats-{roomId}" (각 채팅방별 분리)
        socketManager = SocketManager(
            socketURL: Config.baseURL,
            config: [
                .reconnects(true),
                .reconnectAttempts(-1),
                .extraHeaders(["Authorization": token])
            ]
        )

        // 3. "chat" 이벤트 리스닝
        setupEventHandlers()
        socketClient?.connect()
    }

    private func setupEventHandlers() {
        socketClient?.on("chat") { [weak self] data, ack in
            // JSON → DTO 변환 → Subject로 발행
            if let messageDTO = self?.parseMessage(data) {
                self?.messageSubject.send(messageDTO)
            }
        }
    }
}
```

**Repository에서 Socket 메시지 처리**
```swift
// ChatRepository.swift:661
private func setupSocketMessageListener() {
    socketManager.observeMessages()
        .sink { [weak self] messageDTO in
            let message = messageDTO.toDomain()

            Task { @MainActor in
                // 1. CoreData 중복 확인 (chatId로 조회)
                // 2. .sending 상태의 임시 메시지 삭제 (Optimistic Update 정리)
                // 3. CoreData에 저장
                // 4. Subject 업데이트 → UI 자동 갱신
                try self?.saveMessageToCoreData(message)
                await self?.refreshMessagesFromCoreData(roomId: message.roomId)
            }
        }
        .store(in: &cancellables)
}
```

**기술적 챌린지와 해결**
- **문제**: Socket 메시지와 API 응답 메시지가 중복 저장됨
- **해결**: CoreData 저장 전 `chatId`로 중복 확인, 이미 존재하면 저장 스킵
- **문제**: Optimistic Update로 생성한 임시 메시지(.sending)가 Socket 메시지와 중복
- **해결**: Socket 메시지 수신 시 같은 roomId + senderId + 5초 이내 createdAt을 가진 .sending 메시지 자동 삭제

---

### 3. Optimistic Update 패턴

**Optimistic Update 흐름**
```swift
// ChatRepository.swift:267
func sendMessage(roomId: String, content: String?, files: [String]) async throws -> ChatMessage {
    // 1. Optimistic Update: 로컬 메시지 생성 (.sending 상태)
    let localMessage = ChatMessage.createLocal(
        roomId: roomId,
        content: content,
        senderId: currentUserId,
        files: files
    )

    // 2. CoreData에 .sending 상태로 즉시 저장
    try saveMessageToCoreData(localMessage)
    await refreshMessagesFromCoreData(roomId: roomId)  // UI 즉시 업데이트

    do {
        // 3. API 전송
        let responseDTO = try await networkManager.request(...)

        // 4. 성공: 임시 메시지 삭제 → 서버 응답으로 교체
        try deleteMessageFromCoreData(chatId: localMessage.chatId)
        let sentMessage = responseDTO.toDomain()
        try saveMessageToCoreData(sentMessage)

        return sentMessage

    } catch {
        // 5. 실패: .failed 상태로 업데이트 (재전송 가능)
        let failedMessage = localMessage.with(status: .failed)
        try saveMessageToCoreData(failedMessage)
        throw error
    }
}
```

**MessageSendStatus 상태 관리**
```swift
enum MessageSendStatus: String, Codable {
    case sending   // 전송 중 (API 요청 진행 중)
    case sent      // 전송 완료 (서버 응답 200 OK)
    case failed    // 전송 실패 (네트워크 에러, 서버 에러 등)
}
```

**사용자 경험 개선 효과**
- 메시지 전송 버튼 클릭 즉시 UI에 표시 (네트워크 지연 체감 최소화)
- .sending 상태에서 로딩 인디케이터 표시
- .failed 상태에서 재전송 버튼 노출

---

### 4. Actor 기반 메시지 대기열 및 자동 재전송

**MessageQueueManager (Actor)**
```swift
// MessageQueueManager.swift:17
actor MessageQueueManager {
    struct QueueItem {
        let messageId: String
        let content: String
        let files: [String]
        let isRetry: Bool  // 재전송 여부
    }

    private var queue: [QueueItem] = []  // FIFO 큐
    private var isSending: Bool = false
    private var shouldStop: Bool = false

    // 대기열 처리 (순차 전송)
    func processQueue(
        repository: ChatRepositoryProtocol,
        roomId: String,
        networkMonitor: NetworkMonitor
    ) async -> Int {
        guard !isSending else { return 0 }

        isSending = true
        var successCount = 0

        while !queue.isEmpty && !shouldStop {
            // 네트워크 끊김 확인
            if !networkMonitor.isConnected {
                shouldStop = true
                break
            }

            let item = queue.removeFirst()

            do {
                // 재전송인 경우 기존 메시지 삭제
                if item.isRetry {
                    try await repository.deleteMessage(chatId: item.messageId)
                }

                // 메시지 전송
                _ = try await repository.sendMessage(
                    roomId: roomId,
                    content: item.content,
                    files: item.files
                )
                successCount += 1

            } catch {
                // 네트워크 에러 시 중단, 실패한 아이템 다시 큐 맨 앞에 추가
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        queue.insert(item, at: 0)
                        shouldStop = true
                    default:
                        break
                    }
                }
            }
        }

        isSending = false
        return successCount
    }
}
```

**네트워크 재연결 시 자동 재전송**
```swift
// ChatRoomViewModel.swift:353
private func setupNetworkMonitoring() {
    networkMonitor.networkReconnected
        .sink { [weak self] in
            Task {
                // 1. CoreData에서 실패한 메시지 조회 (24시간 이내, 최근 20개, FIFO)
                let failedMessages = try await self?.repository.fetchFailedMessages(roomId: roomId)

                // 2. 대기열에 추가
                for message in failedMessages {
                    let item = MessageQueueManager.QueueItem(
                        messageId: message.chatId,
                        content: message.content,
                        files: message.files,
                        isRetry: true
                    )
                    await self?.queueManager.enqueue(item)
                }

                // 3. 순차 전송
                await self?.processQueue()
            }
        }
        .store(in: &cancellables)
}
```

**기술적 의사결정**
- **Actor 선택 이유**: DispatchQueue 대신 Actor로 Data Race 방지, async/await와 자연스러운 통합
- **FIFO 큐**: 사용자가 입력한 순서대로 전송하여 자연스러운 대화 흐름 유지
- **네트워크 에러 핸들링**: `.notConnectedToInternet` 등의 에러는 큐 중단 + 아이템 재삽입, 서버 에러는 건너뛰고 계속 진행

---

### 5. CoreData 기반 오프라인 지원 (로컬 우선 전략)

**로컬 우선 전략 (Local-First Strategy)**
```swift
// ChatRepository.swift:120
func fetchChatRooms() async throws -> [ChatRoom] {
    // 1. CoreData에서 로컬 데이터를 먼저 가져오기 (즉시 반환)
    let localChatRooms: [ChatRoom]
    do {
        let entities = try coreDataManager.fetchChatRooms()
        localChatRooms = entities.map { $0.toDomain() }

        // 로컬 데이터가 있으면 Subject 즉시 업데이트 (빠른 UI 표시)
        if !localChatRooms.isEmpty {
            chatRoomsSubject.send(localChatRooms)
        }
    } catch {
        localChatRooms = []
    }

    // 2. 백그라운드에서 네트워크 요청 (비동기)
    Task {
        do {
            let responseDTO = try await networkManager.request(...)
            let chatRooms = responseDTO.data.compactMap { $0.toDomain() }

            // CoreData에 UPSERT
            for chatRoom in chatRooms {
                try saveChatRoomToCoreData(chatRoom)
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
```

**UPSERT 구현 (Insert or Update)**
```swift
// ChatRepository.swift:749
private func saveChatRoomToCoreData(_ chatRoom: ChatRoom) throws {
    // 1. ChatRoomEntity 조회 또는 생성
    let entity = try coreDataManager.upsertChatRoom(
        roomId: chatRoom.roomId,
        createdAt: chatRoom.createdAt,
        updatedAt: chatRoom.updatedAt
    )

    // 2. 상대방 정보 설정
    entity.opponentUserId = chatRoom.opponent.userId
    entity.opponentNick = chatRoom.opponent.nick

    // 3. lastReadAt은 로컬 값이 더 최신이면 유지 (서버 데이터로 덮어쓰지 않음)
    if let existingLastReadAt = entity.lastReadAt,
       let newLastReadAt = chatRoom.lastReadAt {
        entity.lastReadAt = max(existingLastReadAt, newLastReadAt)
    }

    try coreDataManager.saveContext()
}
```

**Relationship 보장 (ChatRoom ↔ ChatMessage)**
```swift
// ChatRoomViewModel.swift:92
init(chatRoom: ChatRoom, ...) {
    // 1. ChatRoom을 먼저 CoreData에 저장 (Relationship 설정 전제조건)
    try repository.ensureChatRoomExists(chatRoom)

    // 2. 명시적으로 디스크에 저장 (relationship 설정 완료 보장)
    try repository.saveChatRoomContext()

    // 3. 이후 메시지 저장 시 chatRoom relationship 안전하게 설정 가능
}
```

**사용자 경험 개선 효과**
- 오프라인 상태에서도 이전 채팅 내역 조회 가능
- 앱 시작 시 로컬 데이터를 먼저 표시하여 빠른 초기 로딩
- 네트워크 에러 시에도 UI가 빈 화면으로 표시되지 않음

---

### 6. 파일 업로드 (multipart/form-data)

**파일 업로드 흐름**
```swift
// ChatRepository.swift:327
func uploadFiles(roomId: String, dataList: [Data], fileExtensions: [String]) async throws -> [String] {
    var allData: [Data] = []
    var allExtensions: [String] = []

    // 1. 동영상 파일 전처리 (mov → mp4 변환)
    for (index, data) in dataList.enumerated() {
        let fileExtension = fileExtensions[index].lowercased()
        let isVideo = ["mp4", "mov", "m4a", "m4v"].contains(fileExtension)

        if isVideo && fileExtension != "mp4" {
            // AVFoundation으로 mp4 변환
            let mp4Data = try await convertVideoToMP4(from: data)
            allData.append(mp4Data)
            allExtensions.append("mp4")
        } else {
            allData.append(data)
            allExtensions.append(fileExtension)
        }
    }

    // 2. NetworkManager의 multipart 업로드
    return try await networkManager.uploadFiles(
        allData,
        fileExtensions: allExtensions,
        config: .chat,  // jpg, png, jpeg, gif, pdf, mp3, mp4 (50MB, 5개)
        endpoint: ChatRouter.uploadFiles(roomId: roomId, imageData: allData)
    )
}
```

**동영상 포맷 변환 (AVFoundation)**
```swift
// ChatRepository.swift:414
private func convertVideoToMP4(from videoData: Data) async throws -> Data {
    // 1. Data를 임시 파일로 저장 (AVAsset은 URL 필요)
    let inputURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mov")
    try videoData.write(to: inputURL)

    defer {
        try? FileManager.default.removeItem(at: inputURL)  // 작업 완료 후 삭제
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
    exportSession.outputFileType = .mp4  // mp4로 변환
    exportSession.shouldOptimizeForNetworkUse = true

    // 4. 변환 시작 (async/await)
    await exportSession.export()

    // 5. 변환된 mp4 파일을 Data로 읽기
    return try Data(contentsOf: outputURL)
}
```

**기술적 챌린지와 해결**
- **문제**: iOS에서 촬영한 .mov 파일을 서버에서 지원하지 않음
- **해결**: AVAssetExportSession으로 클라이언트에서 mp4로 변환 후 업로드
- **문제**: 업로드 중 사용자가 화면을 벗어나면 실패
- **해결**: Repository에서 업로드를 처리하여 ViewModel/ViewController 생명주기와 독립

---

## 🎓 학습 포인트 (신입 개발자 강조)

### 1. Clean Architecture 실전 적용 경험

**도입 배경**
- 초기에는 MVVM만 사용했으나, ViewModel에 네트워크 로직, 비즈니스 로직, UI 로직이 섞이면서 500줄 이상의 거대한 ViewModel 발생
- 기능 추가 시 ViewModel 수정 범위가 넓어져 Side Effect 우려 증가

**리팩토링 과정**
1. **Domain Layer 분리**: SendMessageUsecase, FetchChatRoomsUsecase 생성
   - ViewModel에서 비즈니스 로직(입력 검증, 에러 변환) 제거
   - ViewModel은 Input/Output 변환만 담당하도록 역할 축소
2. **Repository 추상화**: ChatRepositoryProtocol 정의
   - API, CoreData, Socket.IO를 Repository에서 통합
   - ViewModel은 데이터 출처를 몰라도 되므로 Test 시 Mock Repository 주입 가능
3. **Entity/DTO 분리**: 서버 응답 DTO와 Domain Entity 분리
   - 서버 스펙 변경 시 Mapping 레이어에서만 수정

**학습 결과**
- 각 레이어의 역할과 책임을 명확히 이해
- 테스트 가능한 코드 작성의 중요성 체감
- "관심사의 분리(Separation of Concerns)"의 실질적 이점 경험

---

### 2. Actor를 활용한 동시성 안전 보장

**문제 상황**
- 메시지 전송 대기열에서 여러 Task가 동시에 queue에 접근 시 Data Race 발생 가능
- DispatchQueue를 사용할 수도 있었으나, Swift Concurrency 생태계와의 통합 고려

**Actor 도입**
```swift
actor MessageQueueManager {
    private var queue: [QueueItem] = []  // Actor가 자동으로 접근 제어

    func enqueue(_ item: QueueItem) {  // async 없어도 안전
        queue.append(item)
    }

    func processQueue(...) async -> Int {
        // Actor 내부에서만 queue 변경 가능
    }
}
```

**학습 결과**
- Actor의 "Actor Isolation" 개념 이해 (컴파일러 수준에서 Data Race 방지)
- async/await와 Actor의 시너지 (await으로 Actor 메서드 호출)
- Sendable Protocol의 중요성 (Actor 간 데이터 전달 안전성)

---

### 3. Combine을 활용한 반응형 프로그래밍

**Combine 도입 계기**
- 채팅방 목록, 메시지 목록이 실시간으로 변경되는데 NotificationCenter로는 복잡도 증가
- CoreData 변경 → ViewModel 업데이트 → UI 갱신 흐름을 선언적으로 표현하고 싶었음

**Publisher 체인 구성**
```swift
// Repository에서 Publisher 제공
func observeMessages(roomId: String) -> AnyPublisher<[ChatMessage], Never> {
    return messagesSubjects[roomId]!.eraseToAnyPublisher()
}

// ViewModel에서 구독
private func setupRealtimeUpdates() {
    repository.observeMessages(roomId: roomId)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] messages in
            self?.messagesSubject.send(messages)
        }
        .store(in: &cancellables)
}
```

**학습 결과**
- Publisher/Subscriber 패턴의 장점 (느슨한 결합, 다대다 관계)
- Subject의 종류와 사용 시나리오 (CurrentValueSubject vs PassthroughSubject)
- Combine Operator 체인 (map, filter, debounce 등)의 강력함

---

### 4. 오프라인 지원과 데이터 정합성

**핵심 전략: 로컬 우선 + UPSERT**
- API 응답을 기다리지 않고 CoreData 데이터를 먼저 반환 (빠른 UI)
- 백그라운드에서 네트워크 요청 → CoreData UPSERT → Subject 업데이트
- 네트워크 실패 시에도 로컬 데이터로 정상 동작

**UPSERT 구현**
```swift
func upsertChatMessage(chatId: String, ...) throws -> ChatMessageEntity {
    let fetchRequest = ChatMessageEntity.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "chatId == %@", chatId)

    let results = try viewContext.fetch(fetchRequest)

    if let existing = results.first {
        // 업데이트
        existing.content = content
        existing.status = status
        return existing
    } else {
        // 삽입
        let newEntity = ChatMessageEntity(context: viewContext)
        newEntity.chatId = chatId
        return newEntity
    }
}
```

**학습 결과**
- UPSERT 패턴의 중요성 (중복 방지, 데이터 정합성 보장)
- CoreData Relationship 관리의 어려움 (ChatRoom이 먼저 저장되어야 ChatMessage 저장 가능)
- 로컬 데이터 우선 전략의 사용자 경험 개선 효과

---

## ⚠️ 개선 포인트 및 한계점

### 1. Socket.IO 메시지 중복 처리의 불완전성

**현재 상황**
```swift
// ChatRepository.swift:685
// .sending 상태의 로컬 임시 메시지 삭제 (중복 방지)
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
```

**문제점**
- 5초 이내 같은 사용자가 여러 메시지를 빠르게 보내면 잘못된 메시지가 삭제될 가능성
- content나 files를 비교하지 않고 시간과 senderId만으로 판별

**개선 방안**
1. **클라이언트 임시 ID 서버 전송**:
   - 메시지 전송 시 `tempId` 필드를 서버에 전달
   - 서버가 응답에 `tempId`를 포함시켜 반환
   - Socket 메시지에도 `tempId` 포함
   - `tempId`로 정확한 매칭 가능

```swift
// 개선된 방식
struct SendMessageRequestDTO: Encodable {
    let content: String?
    let files: [String]?
    let tempId: String  // 클라이언트 임시 ID 추가
}

// Socket 메시지 수신 시
if let tempId = messageDTO.tempId {
    // tempId로 정확히 매칭
    let tempMessageRequest = ChatMessageEntity.fetchRequest()
    tempMessageRequest.predicate = NSPredicate(format: "chatId == %@", tempId)
    // ...
}
```

2. **Content Hash 비교**:
   - content + files를 조합한 해시값 생성
   - 시간 범위 + 해시 일치로 더 정확한 판별

---

### 2. CoreData Relationship 관리의 복잡성

**현재 문제**
```swift
// ChatRoomViewModel.swift:92
// 채팅방 정보를 먼저 CoreData에 저장해야 메시지를 저장할 수 있음
do {
    try repository.ensureChatRoomExists(chatRoom)
    try repository.saveChatRoomContext()  // 명시적 저장 필요
} catch {
    print("❌ 채팅방 저장 실패: \(error)")
    // 실패 시 앱 정상 작동 불가
}
```

**문제점**
- ChatRoom Entity가 먼저 저장되지 않으면 ChatMessage의 relationship 설정 실패로 크래시 발생
- `ensureChatRoomExists()` + `saveChatRoomContext()` 두 번 호출 필요 (실수 유발)
- ViewModel 초기화 시 동기적으로 처리해야 해서 에러 처리 어려움

**개선 방안**
1. **Repository에서 자동으로 ChatRoom 생성**:
```swift
// ChatRepository 내부 개선
func sendMessage(roomId: String, ...) async throws -> ChatMessage {
    // 1. ChatRoom 자동 확인 및 생성
    try await ensureRoomExistsWithMinimalData(roomId: roomId)

    // 2. 메시지 저장
    let localMessage = ChatMessage.createLocal(...)
    try saveMessageToCoreData(localMessage)
}

private func ensureRoomExistsWithMinimalData(roomId: String) async throws {
    // CoreData 조회 → 없으면 최소한의 정보로 생성
    // ViewModel에서 신경 쓸 필요 없게
}
```

2. **Optional Relationship으로 변경**:
   - ChatMessage의 chatRoom relationship을 optional로 설정
   - Relationship이 없어도 저장 가능하게 하고, 나중에 연결

---

### 3. 메시지 전송 실패 시 복구 전략의 한계

**현재 한계**
```swift
// ChatRepository.swift:582
func fetchFailedMessages(roomId: String) async throws -> [ChatMessage] {
    // 조건: status가 .failed, 24시간 이내, 최근 20개
    fetchRequest.predicate = NSPredicate(
        format: "roomId == %@ AND status == %@ AND createdAt >= %@",
        roomId,
        MessageSendStatus.failed.rawValue,
        twentyFourHoursAgo as NSDate
    )
    fetchRequest.fetchLimit = 20
}
```

**문제점**
- 24시간 이후 실패 메시지는 자동 재전송 대상에서 제외됨
- 20개 이상 실패하면 오래된 메시지는 재전송되지 않음
- 사용자가 수동으로 재전송 버튼을 눌러야 함

**개선 방안**
1. **Persistent Queue (CoreData 기반)**:
```swift
// FailedMessageQueue Entity 생성
entity FailedMessageQueue {
    messageId: String
    roomId: String
    content: String
    files: [String]
    failedAt: Date
    retryCount: Int  // 재시도 횟수
    nextRetryAt: Date?  // 다음 재시도 시각 (Exponential Backoff)
}

// Exponential Backoff 적용
func scheduleRetry(message: FailedMessageQueue) {
    let delay = pow(2.0, Double(message.retryCount)) * 60  // 1분, 2분, 4분, ...
    message.nextRetryAt = Date().addingTimeInterval(delay)
}
```

2. **Background Task로 재전송**:
   - `BGTaskScheduler`로 백그라운드에서 주기적으로 실패 메시지 재전송
   - 앱이 종료되어도 시스템이 자동으로 재시도

---

### 4. 파일 업로드 진행률 표시 부재

**현재 한계**
```swift
// ChatRoomViewModel.swift:485
let fileUrls = try await repository.uploadFiles(
    roomId: roomId,
    dataList: [data],
    fileExtensions: [fileExtension]
)
// 업로드 중 진행률 알 수 없음
```

**문제점**
- 대용량 파일(동영상 등) 업로드 시 사용자는 진행 상황을 알 수 없음
- 네트워크가 느린 환경에서 앱이 멈춘 것처럼 보일 수 있음

**개선 방안**
1. **AsyncStream으로 진행률 전달**:
```swift
// Repository에서 AsyncStream 반환
func uploadFiles(...) -> AsyncThrowingStream<UploadProgress, Error> {
    AsyncThrowingStream { continuation in
        alamofireSession.upload(multipartFormData: ..., to: url)
            .uploadProgress { progress in
                continuation.yield(.progress(progress.fractionCompleted))
            }
            .response { response in
                if response.error != nil {
                    continuation.finish(throwing: error)
                } else {
                    continuation.yield(.completed(urls))
                    continuation.finish()
                }
            }
    }
}

enum UploadProgress {
    case progress(Double)  // 0.0 ~ 1.0
    case completed([String])  // 업로드된 URL
}
```

2. **ViewModel에서 진행률 Subject 업데이트**:
```swift
private let uploadProgressSubject = CurrentValueSubject<Double, Never>(0.0)

for await progress in repository.uploadFiles(...) {
    switch progress {
    case .progress(let value):
        uploadProgressSubject.send(value)
    case .completed(let urls):
        // 메시지 전송
    }
}
```

---

### 5. 읽지 않은 메시지 배지의 서버 동기화 부재

**현재 한계**
```swift
// ChatRoom.swift:42
// lastReadAt은 로컬에서만 관리
var lastReadAt: Date?

// ChatRepository.swift:534
func updateLastReadDate(roomId: String) async throws {
    chatRoomEntity.lastReadAt = Date()
    try coreDataManager.saveContext()
    // 서버로 전송하지 않음
}
```

**문제점**
- 다른 기기(iPad, Mac)에서 같은 계정으로 로그인 시 읽은 시간이 동기화되지 않음
- 앱 재설치 시 읽은 시간이 초기화됨 (CoreData 삭제)

**개선 방안**
1. **서버 API에 lastReadAt 전송**:
```swift
// ChatRouter에 새 엔드포인트 추가
case updateLastRead(roomId: String, lastReadAt: Date)

// Repository에서 API 호출
func updateLastReadDate(roomId: String) async throws {
    // 1. 로컬 업데이트
    chatRoomEntity.lastReadAt = Date()
    try coreDataManager.saveContext()

    // 2. 서버 동기화 (Fire and Forget - 실패해도 무시)
    Task {
        try? await networkManager.request(
            ChatRouter.updateLastRead(roomId: roomId, lastReadAt: Date()),
            type: EmptyResponse.self
        )
    }
}
```

2. **서버에서 lastReadAt 반환**:
   - 채팅방 목록 조회 시 서버가 lastReadAt 포함
   - 로컬 값과 비교하여 더 최신 값 사용

---

## 🚀 추후 확장 가능성

### 1. 그룹 채팅 지원

**현재 1:1 채팅 구조**
```swift
struct ChatRoom {
    let opponent: Opponent  // 단일 상대방
}
```

**그룹 채팅 확장**
```swift
struct ChatRoom {
    let roomType: RoomType  // .direct, .group
    let participants: [Participant]  // 여러 참여자 지원
    let title: String?  // 그룹 이름
    let adminId: String?  // 방장 ID
}

enum RoomType {
    case direct  // 1:1
    case group   // 그룹
}
```

**필요한 변경사항**
- CoreData Entity에 participants Relationship 추가
- UI에서 참여자 목록 표시
- 그룹 생성/초대/나가기 API 연동

---

### 2. 메시지 검색 기능

**CoreData Full-Text Search 활용**
```swift
// ChatMessageEntity에 Spotlight 인덱싱 추가
extension ChatMessageEntity {
    @NSManaged var searchableContent: String
}

// Fetch Request with NSPredicate
func searchMessages(keyword: String) -> [ChatMessage] {
    let fetchRequest = ChatMessageEntity.fetchRequest()
    fetchRequest.predicate = NSPredicate(
        format: "searchableContent CONTAINS[cd] %@",
        keyword
    )
    // [cd]: case-insensitive, diacritic-insensitive
}
```

**UI 개선**
- 채팅방 목록 상단에 검색 바 추가
- 검색 결과에서 해당 메시지로 스크롤

---

### 3. 메시지 반응 (Reaction) 기능

**Entity 확장**
```swift
struct ChatMessage {
    let reactions: [Reaction]  // 반응 목록 추가
}

struct Reaction: Codable {
    let emoji: String  // "👍", "❤️", ...
    let userId: String
    let createdAt: Date
}
```

**Socket.IO 이벤트 추가**
```swift
// 서버에서 "reaction" 이벤트 수신
socketClient?.on("reaction") { data, ack in
    // Reaction DTO → CoreData 업데이트 → UI 갱신
}
```

**UI 구현**
- 메시지 길게 누르면 반응 선택 팝업
- 메시지 하단에 반응 목록 표시 (그룹화)

---

### 4. 메시지 암호화 (End-to-End Encryption)

**CryptoKit 활용**
```swift
import CryptoKit

// 공개키/개인키 생성
let privateKey = Curve25519.KeyAgreement.PrivateKey()
let publicKey = privateKey.publicKey

// 메시지 암호화
func encryptMessage(content: String, recipientPublicKey: Curve25519.KeyAgreement.PublicKey) -> Data {
    let sharedSecret = try! privateKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)
    let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(...)

    let sealedBox = try! AES.GCM.seal(content.data(using: .utf8)!, using: symmetricKey)
    return sealedBox.combined!
}
```

**서버 변경 필요**
- 서버는 암호화된 데이터만 전달 (복호화 불가)
- 클라이언트 간 공개키 교환 API 필요

---

### 5. 메시지 번역 기능

**Apple Translation Framework 활용**
```swift
import Translation

// iOS 15+ Translation API
func translateMessage(content: String, targetLanguage: Locale.Language) async throws -> String {
    let session = TranslationSession()
    let response = try await session.translate(content, to: targetLanguage)
    return response.targetText
}
```

**UI 구현**
- 메시지 길게 누르면 "번역" 옵션
- 번역 결과를 말풍선 아래에 표시
- CoreData에 번역 결과 캐싱 (같은 메시지 재번역 방지)

---

## 📊 포트폴리오 강조 포인트 (스타트업 어필)

### 1. 빠른 개발 속도와 품질의 균형

**MVP 우선 접근**
- 1차: 기본 채팅 송수신 (Socket.IO + API) 구현 (3일)
- 2차: Optimistic Update 추가 (1일)
- 3차: 실패 메시지 재전송 (대기열 + Actor) (2일)
- 4차: 오프라인 지원 (CoreData 로컬 우선 전략) (2일)

**빠르게 검증 후 점진적 개선**
- 초기에는 Socket.IO 없이 Polling으로 시작 (빠른 검증)
- 사용자 피드백 후 Socket.IO로 전환 (실시간성 개선)
- 테스트 코드는 핵심 비즈니스 로직(UseCase)에만 집중

---

### 2. 확장 가능한 구조 설계

**프로토콜 기반 설계**
```swift
protocol ChatRepositoryProtocol {
    func sendMessage(...) async throws -> ChatMessage
}

// Test 시 Mock 주입 가능
class MockChatRepository: ChatRepositoryProtocol {
    var shouldFail = false

    func sendMessage(...) async throws -> ChatMessage {
        if shouldFail {
            throw TestError.networkError
        }
        return ChatMessage(...)
    }
}
```

**새로운 기능 추가 용이**
- 그룹 채팅 추가 시: `ChatRoom.participants` 확장만으로 대부분 대응 가능
- 메시지 타입 추가 시: `ChatMessage` Entity에 타입 필드만 추가
- Repository 구조 덕분에 데이터 소스 변경(Firebase, GraphQL 등)도 쉬움

---

### 3. 실제 비즈니스 요구사항 반영

**네트워크 불안정 대응**
- 지하철, 엘리베이터 등 네트워크 끊김 상황 고려
- 오프라인 모드에서도 채팅 내역 조회 가능
- 네트워크 재연결 시 자동으로 실패 메시지 재전송

**사용자 경험 우선**
- Optimistic Update로 즉각적인 피드백
- 로컬 우선 전략으로 빠른 초기 로딩
- 메시지 전송 상태(.sending, .sent, .failed) 명확히 표시

**확장성 고려**
- Clean Architecture로 비즈니스 로직 독립
- Actor로 동시성 안전 보장 (Scale-up 대비)
- CoreData Relationship으로 그룹 채팅 확장 가능

---

### 4. 유지보수 가능한 코드 작성 노력

**문서화**
```swift
/// 메시지 전송 대기열 관리자
///
/// 역할:
/// 1. 실패한 메시지와 새 메시지를 순차적으로 전송 (FIFO)
/// 2. 네트워크 끊김 시 전송 중단
/// 3. 전송 중 사용자 메시지는 대기열 맨 뒤에 추가
actor MessageQueueManager { ... }
```

**명확한 네이밍**
- `ChatRepositoryProtocol` (역할 명확)
- `SendMessageUsecase` (행위 중심)
- `MessageSendStatus` (상태 명확)

**에러 처리**
```swift
enum SendMessageError: LocalizedError {
    case emptyMessage
    case messageTooLong
    case networkError

    var errorDescription: String? {
        // 사용자에게 표시할 명확한 메시지
    }
}
```

**테스트 가능성**
- Protocol 기반 설계로 Mock 주입 가능
- UseCase가 독립적이어서 Unit Test 작성 용이
- Repository가 데이터 소스를 추상화하여 Test Double 사용 가능

---

## 🔗 관련 코드 위치

### Domain Layer
- `Feelter/Domain/Entity/Chat/ChatMessage.swift:10` - ChatMessage Entity
- `Feelter/Domain/Entity/Chat/ChatRoom.swift:10` - ChatRoom Entity
- `Feelter/Domain/Entity/Chat/MessageSendStatus.swift:11` - 메시지 전송 상태
- `Feelter/Domain/Usecase/Chat/SendMessageUsecase.swift:10` - 메시지 전송 UseCase
- `Feelter/Domain/Manager/MessageQueueManager.swift:17` - 메시지 대기열 (Actor)
- `Feelter/Domain/RepositoryProtocol/ChatRepositoryProtocol.swift:11` - Repository Protocol

### Data Layer
- `Feelter/Data/Repository/ChatRepository.swift:26` - Repository 구현체
- `Feelter/Data/Network/Routers/ChatRouter.swift:11` - API Router
- `Feelter/Data/Socket/SocketIOManager.swift:55` - Socket.IO Manager
- `Feelter/Data/Network/Base/NetworkMonitor.swift:19` - 네트워크 모니터

### Presentation Layer
- `Feelter/Presentation/Chat/ChatRoom/ChatRoomViewModel.swift:12` - ViewModel (Input/Output)
- `Feelter/Presentation/Chat/ChatRoom/ChatRoomViewController.swift:17` - ViewController

---

## 마무리

이 채팅 기능은 단순한 메시지 송수신을 넘어, **실제 프로덕션 환경에서 발생할 수 있는 다양한 엣지 케이스를 고려한 설계**입니다.

특히 **네트워크 불안정 상황**에서의 안정성, **오프라인 지원**, **동시성 안전**을 중요하게 생각했으며, Clean Architecture를 통해 **테스트 가능하고 확장 가능한 구조**를 만들기 위해 노력했습니다.

신입 개발자로서 **아키텍처 패턴의 실전 적용**, **Swift Concurrency의 깊은 이해**, **Combine을 활용한 반응형 프로그래밍** 경험을 쌓을 수 있었고, 스타트업 환경에서 요구되는 **빠른 개발 속도와 품질의 균형**을 맞추는 법을 배웠습니다.
