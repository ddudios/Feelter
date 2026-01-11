# Feelter 채팅 기능 구현 가이드

## 📋 개발 원칙

### 1. 단계별 구현 (Step-by-Step)
- **한 번에 모든 코드를 작성하지 않습니다**
- 각 단계마다 개념 설명 → 구현 이유 → 코드 작성 순서로 진행
- 새로운 개념이 나올 때마다 상세히 설명

### 2. 학습 목표
- Clean Architecture 실전 적용
- MVVM + Input/Output Pattern 이해
- Combine을 활용한 반응형 프로그래밍
- CoreData를 활용한 로컬 데이터 관리
- Coordinator Pattern으로 화면 전환 관리
- Socket.IO와 REST API의 조합

---

## 🏗️ 아키텍처 개요

### Clean Architecture 계층 구조

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│  (ViewController, ViewModel, Coordinator)│
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│          Domain Layer                   │
│     (Entity, UseCase, Protocol)         │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│           Data Layer                    │
│  (Repository, DTO, CoreData, Network)   │
└─────────────────────────────────────────┘
```

#### 각 계층의 역할

**1. Domain Layer (핵심 비즈니스 로직)**
- `Entity`: 순수 Swift 구조체/클래스 (비즈니스 모델)
- `UseCase`: 특정 기능의 비즈니스 로직 (예: 메시지 전송)
- `RepositoryProtocol`: 데이터 접근 인터페이스 정의

**2. Data Layer (데이터 처리)**
- `Repository`: RepositoryProtocol 구현체
- `DTO`: API 응답/요청 데이터 구조
- `Mapping`: DTO ↔ Entity 변환
- `CoreData`: 로컬 데이터베이스

**3. Presentation Layer (UI)**
- `ViewController`: 화면 표시 및 사용자 입력 처리
- `ViewModel`: UI 로직 및 상태 관리 (Input/Output)
- `Coordinator`: 화면 전환 흐름 관리

---

## 🎯 채팅 기능 핵심 개념

### 1. 왜 Socket.IO인가?

#### Socket.IO의 장점
1. **자동 재연결**: 네트워크 끊김 시 자동으로 재연결 시도
2. **룸(Room) 개념**: 채팅방 단위 메시지 송수신 간편
3. **Fallback**: WebSocket 미지원 환경에서 Long Polling으로 전환
4. **이벤트 기반**: 명확한 이벤트 리스너로 관리 용이

#### 연결 방식
```
http://{baseURL}:{port}/chats-{room_id}
```

---

### 2. 3가지 데이터 소스 (DB + REST API + Socket)

```
┌──────────────┐
│   CoreData   │ ← 로컬 캐시, 빠른 로딩
└──────┬───────┘
       │
┌──────▼───────┐
│  REST API    │ ← 신뢰성 있는 데이터, 동기화
└──────┬───────┘
       │
┌──────▼───────┐
│  Socket.IO   │ ← 실시간 메시지
└──────────────┘
```

#### A. CoreData (로컬 DB)
**역할**: 오프라인 지원 및 빠른 UX
- 앱 시작 시 바로 이전 대화 표시
- 네트워크 없이도 읽기 가능
- 저장 대상: 채팅방 정보, 메시지, 전송 상태

#### B. REST API
**역할**: 데이터 동기화 및 신뢰성 보장
- 채팅방 진입 시 서버와 동기화
- `next` 파라미터로 마지막 이후 메시지만 가져옴
- 사용 시점:
  - 채팅방 목록 조회
  - 채팅방 진입 시
  - 메시지 전송

#### C. Socket.IO
**역할**: 실시간 메시지 수신
- 현재 접속 중일 때만 동작
- 상대방이 보낸 메시지 즉시 수신
- 이벤트:
  - `connect`: 연결 성공
  - `chat`: 새 메시지 수신
  - `disconnect`: 연결 해제

---

### 3. 데이터 정합성 보장 (유실 방지 + 중복 방지)

#### 문제 상황
```
시간축:
0초 ─────► 채팅방 진입
1초 ─────► Socket 연결 시작
2초 ─────► 상대방 메시지 전송 (Socket으로 수신)
3초 ─────► Socket 연결 완료
4초 ─────► REST API 요청
5초 ─────► API 응답 (2초 메시지 포함)
         ⚠️ 2초 메시지가 중복!
```

#### 해결 방법: UPSERT 전략

**핵심 아이디어**: `chat_id`를 Primary Key로 사용

```swift
// CoreData 저장 로직 (Repository에서 처리)
func saveMessage(_ message: ChatMessage) {
    // chat_id가 이미 존재하면 무시 (중복 방지)
    // 없으면 새로 저장
}
```

#### 권장 흐름

1. **채팅방 진입**
   ```swift
   func enterChatRoom(roomId: String) {
       // 1. Socket 연결 시작
       socketManager.connect(roomId: roomId)

       // 2. DB에서 마지막 메시지 시간 가져오기
       let lastDate = fetchLastMessageDate(roomId: roomId)

       // 3. REST API로 이후 메시지 가져오기
       fetchChatHistory(roomId: roomId, after: lastDate)
   }
   ```

2. **메시지 병합 (Repository)**
   ```swift
   func syncMessages(from api: [ChatMessage]) {
       // API로 받은 메시지를 순회
       for message in api {
           // chat_id로 UPSERT
           saveOrUpdateMessage(message)
       }
   }
   ```

3. **Socket 메시지 처리**
   ```swift
   socketManager.onMessageReceived
       .sink { [weak self] message in
           // 똑같이 UPSERT (중복 자동 제거)
           self?.repository.saveMessage(message)
       }
   ```

---

### 4. 메시지 전송: HTTP POST vs Socket Emit

#### 왜 HTTP POST인가?

```
POST /v1/chats/{room_id}
```

**장점**:
1. **명확한 상태 관리**: 200 OK, 400 Error, 500 Error
2. **재전송 로직 구현 용이**: 실패 시 UI에 "재전송" 버튼 표시
3. **응답 데이터 활용**: 서버에서 생성한 `chat_id` 받아 로컬 업데이트

#### 전송 흐름

```
사용자 입력
    │
    ▼
┌────────────────┐
│ Optimistic UI  │ ← 즉시 화면에 표시 (전송 중 상태)
└────────┬───────┘
         │
         ▼
┌────────────────┐
│  HTTP POST     │
└────┬───────┬───┘
     │       │
   성공     실패
     │       │
     ▼       ▼
   완료    재전송
```

**구현 예시**:
```swift
// 1. Optimistic Update (바로 UI 반영)
viewModel.messages.append(newMessage)

// 2. API 전송
let result = await chatRepository.sendMessage(roomId, content)

// 3. 결과 처리
switch result {
case .success(let serverMessage):
    // 서버에서 받은 chat_id로 업데이트
    updateMessageStatus(localId, with: serverMessage.chatId)
case .failure:
    // 전송 실패 표시
    markMessageAsFailed(localId)
}
```

---

### 5. CoreData 설계 전략

#### 왜 CoreData인가?

**장점**:
- Apple First Party (외부 의존성 없음)
- Combine과 완벽한 호환
- Faulting (필요할 때만 메모리 로드)
- NSFetchedResultsController로 자동 UI 업데이트

**vs Realm**:
- Realm: 간결한 코드, 빠른 속도, 러닝커브 낮음
- CoreData: iOS 생태계 밀착, 학습 가치 높음

#### Entity 설계

**ChatRoomEntity**
```swift
- room_id: String (Primary Key)
- createdAt: Date
- updatedAt: Date
- lastReadAt: Date? (로컬에서만 관리)
- participants: [UserEntity]
```

**ChatMessageEntity**
```swift
- chat_id: String (Primary Key)
- room_id: String
- content: String
- senderId: String
- createdAt: Date
- status: String (sending, sent, failed)
- files: [String]?
```

#### CoreData ↔ Domain Entity 매핑

```swift
// Data Layer (CoreData)
class ChatMessageEntity: NSManagedObject { }

// Domain Layer (순수 Swift)
struct ChatMessage {
    let chatId: String
    let content: String
    // ...
}

// Mapping
extension ChatMessageEntity {
    func toDomain() -> ChatMessage {
        ChatMessage(
            chatId: chat_id ?? "",
            content: content ?? ""
        )
    }
}
```

---

### 6. Combine 핵심 개념

#### Publisher vs Subscriber

```swift
// Publisher: 값을 발행하는 주체
let messagePublisher = PassthroughSubject<ChatMessage, Never>()

// Subscriber: 값을 구독하는 주체
messagePublisher
    .sink { message in
        print("새 메시지: \(message)")
    }
    .store(in: &cancellables)
```

#### 자주 사용하는 Operator

1. **map**: 값 변환
   ```swift
   messagesPublisher
       .map { $0.count } // 메시지 개수로 변환
       .sink { count in print("\(count)개") }
   ```

2. **filter**: 조건 필터
   ```swift
   messagesPublisher
       .filter { $0.roomId == currentRoomId }
       .sink { /* ... */ }
   ```

3. **debounce**: 중복 입력 방지
   ```swift
   searchTextPublisher
       .debounce(for: 0.3, scheduler: DispatchQueue.main)
       .sink { /* 검색 */ }
   ```

4. **combineLatest**: 여러 Publisher 결합
   ```swift
   Publishers.CombineLatest(messagesPublisher, roomPublisher)
       .sink { messages, room in /* ... */ }
   ```

---

### 7. Input/Output Pattern

#### 개념
```swift
protocol ViewModelProtocol {
    associatedtype Input
    associatedtype Output

    func transform(input: Input) -> Output
}
```

#### 역할 분리

**Input**: 사용자 액션 (ViewController → ViewModel)
```swift
struct Input {
    let sendButtonTapped: AnyPublisher<String, Never>
    let viewDidLoad: AnyPublisher<Void, Never>
}
```

**Output**: UI 업데이트 데이터 (ViewModel → ViewController)
```swift
struct Output {
    let messages: AnyPublisher<[ChatMessage], Never>
    let isSending: AnyPublisher<Bool, Never>
}
```

#### 흐름
```
ViewController                ViewModel
    │                            │
    │── Input (sendTapped) ──────▶ UseCase 실행
    │                            │
    │◀─ Output (messages) ────── Repository 호출
    │                            │
   UI 업데이트               데이터 가공
```

---

### 8. Coordinator Pattern 사고방식

#### 왜 필요한가?

**문제점**: ViewController가 화면 전환 로직을 직접 가지면
- 재사용성 저하
- 테스트 어려움
- 의존성 증가

**해결책**: Coordinator가 전환 로직 담당

#### 역할
```swift
protocol Coordinator {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get set }
    func start()
}
```

#### 채팅 화면 전환 예시

```
AppCoordinator
    │
    ├─ AuthCoordinator (로그인)
    │
    └─ MainTabBarCoordinator
            │
            ├─ HomeCoordinator
            │
            └─ ChatCoordinator ← 여기서 구현
                    │
                    ├─ showChatRoomList()
                    │
                    └─ showChatRoom(roomId: String)
```

**구현 흐름**:
```swift
class ChatCoordinator: Coordinator {
    func start() {
        // 채팅방 목록 화면 표시
        showChatRoomList()
    }

    func showChatRoom(roomId: String) {
        let viewModel = ChatRoomViewModel(roomId: roomId)
        let viewController = ChatRoomViewController(viewModel: viewModel)

        // ViewModel에서 Coordinator 호출하지 않음!
        // 대신 Delegate나 Closure 사용
        viewController.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }

        navigationController.pushViewController(viewController, animated: true)
    }
}
```

---

## 🔄 전체 데이터 흐름

### 채팅방 진입 시나리오

```
1. 사용자 "채팅방" 탭
   │
   ▼
2. Coordinator.showChatRoom(roomId)
   │
   ▼
3. ViewModel.transform(input: .viewDidLoad)
   │
   ├─ Socket 연결
   ├─ DB에서 마지막 메시지 시간 조회
   └─ API 요청 (next: lastMessageDate)
   │
   ▼
4. Repository
   │
   ├─ CoreData 쿼리
   ├─ API 호출 (Alamofire)
   └─ Socket 이벤트 리스닝
   │
   ▼
5. 데이터 병합
   │
   ├─ API 응답 메시지들을 UPSERT
   ├─ Socket 메시지도 UPSERT
   └─ CoreData 변경 감지
   │
   ▼
6. Output.messages 발행
   │
   ▼
7. ViewController가 Combine으로 구독
   │
   ▼
8. TableView/CollectionView 업데이트
```

---

## 📝 구현 순서

### Phase 1: 기초 설정
1. ✅ 프로젝트 구조 파악
2. ⬜ Clean Architecture 폴더 생성
3. ⬜ CoreData 모델 설계 및 생성

### Phase 2: Domain Layer
4. ⬜ Entity 정의 (ChatRoom, ChatMessage, User)
5. ⬜ Repository Protocol 정의
6. ⬜ UseCase 정의

### Phase 3: Data Layer
7. ⬜ DTO 정의
8. ⬜ DTO ↔ Entity Mapping
9. ⬜ CoreData CRUD 구현
10. ⬜ REST API Repository 구현
11. ⬜ Socket.IO Manager 구현

### Phase 4: Presentation Layer
12. ⬜ ChatCoordinator 구현
13. ⬜ ChatRoomListViewModel 구현
14. ⬜ ChatRoomListViewController 구현
15. ⬜ ChatRoomViewModel 구현
16. ⬜ ChatRoomViewController 구현

### Phase 5: 고급 기능
17. ⬜ 메시지 전송 실패 처리
18. ⬜ 재전송 로직
19. ⬜ 파일 업로드
20. ⬜ 안 읽은 메시지 Badge

---

## 💡 학습 포인트

### 각 단계에서 배울 내용

**CoreData 단계**:
- Entity 설계 방법
- Relationship 설정
- NSFetchedResultsController 사용법
- Thread-Safe 처리 (NSManagedObjectContext)

**Combine 단계**:
- Publisher/Subscriber 개념
- Subject (PassthroughSubject, CurrentValueSubject)
- Operator (map, filter, combineLatest, debounce)
- Memory Management (AnyCancellable)

**Socket.IO 단계**:
- 연결/해제 생명주기
- 이벤트 리스닝
- 에러 처리
- 재연결 전략

**Coordinator 단계**:
- 화면 전환 추상화
- ViewModel-Coordinator 통신 (Delegate vs Closure)
- Child Coordinator 관리

---

## ⚠️ 주의사항

### 1. Thread Safety
- CoreData: MainContext는 Main Thread에서만!
- Socket.IO: 백그라운드 쓰레드 이벤트 처리 주의
- Combine: `.receive(on:)` 활용

### 2. Memory Leak 방지
- `[weak self]` 사용
- Combine `store(in: &cancellables)`
- Coordinator의 Child 제거

### 3. 에러 처리
- Network 에러
- CoreData 에러
- Socket 연결 실패

---

## 📚 참고 자료

- Clean Architecture: https://blog.cleancoder.com/
- Combine: Apple Developer Documentation
- CoreData: Apple Core Data Programming Guide
- Socket.IO Client: https://github.com/socketio/socket.io-client-swift

---

**마지막 업데이트**: 2026-01-11
