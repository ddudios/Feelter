# CoreData 기반 1:1 채팅 구현 정리 (면접 답변용)

## 1) 한 줄 요약
- 이전 프로젝트에서 Realm의 빠른 개발 경험은 있었지만, 이번 프로젝트는 iOS 장기 유지보수성과 애플 생태계 정합성을 우선해서 CoreData를 선택했고, 실시간성은 `Socket + CoreData + Combine Subject` 조합으로 구현했습니다.

## 2) FRC / DiffableDataSource 사용 여부
- `NSFetchedResultsController` 사용: **아니오**
- `DiffableDataSource` 사용: **아니오 (채팅 화면 기준)**
- 현재 방식: `Repository.observeMessages(roomId:)`를 ViewModel이 구독하고, ViewController가 `UITableView.reloadData()`로 반영

### 왜 이렇게 구현했는가
- 채팅 UI 특성상 단순 리스트가 아니라, 날짜 구분선 삽입/시간 표시 규칙/프로필 노출 규칙/실패 메시지 상태 표시 같은 커스텀 후처리가 많았습니다.
- 그래서 FRC delegate 이벤트를 그대로 뷰에 매핑하기보다, `Domain -> ViewItem 변환 + 규칙 계산 -> 전체 아이템 재구성` 흐름이 유지보수에 유리하다고 판단했습니다.
- 1:1 채팅 화면은 일반적으로 한 방에서 처리하는 데이터 범위가 비교적 제한적이라, 현재 단계에서는 전체 reload 전략을 수용했습니다.

## 3) Realm 경험을 바탕으로 CoreData 설계 시 고려한 포인트

### 3-1. "Realm의 라이브 업데이트 장점"을 CoreData에서 어떻게 대체했나
- Realm의 `Results`처럼 자동 반영되는 UX를 유지하려고, 저장소 레이어에서 변경 시점마다 Subject를 갱신하도록 설계했습니다.
- 흐름: `Socket/API -> CoreData 저장(UPSERT) -> refreshMessagesFromCoreData -> messagesSubject.send -> ViewModel Output -> UI 반영`

### 3-2. CoreData 복잡도(컨텍스트/동시성) 관리
- CoreData 접근을 `CoreDataManager`와 `Repository` 내부로 숨겨 Presentation/Domain에 노출하지 않았습니다.
- 컨텍스트는 `performAndWait` 및 `@MainActor` 경계를 명시해 스레드 안정성을 우선했습니다.

### 3-3. Thread confinement / 관계 무결성 이슈 대응
- 메시지 저장 전에 채팅방 엔티티 존재를 강제(`ensureChatRoomExists`, relationship 사전 보장)했습니다.
- 저장 로직에서 `chatRoom` relationship이 없으면 에러를 발생시켜 데이터 불일치 크래시를 방지했습니다.

### 3-4. 실시간성 + 신뢰성(전송 실패/재시도) 동시 확보
- 전송 시 Optimistic Update(`.sending`)를 먼저 저장하고 UI에 즉시 반영했습니다.
- 실패 시 `.failed` 상태로 저장해 사용자 재시도 UX를 제공했습니다.
- 네트워크 재연결 시 실패 메시지 자동 재전송 큐를 돌려 복구 가능성을 높였습니다.

### 3-5. 성능 관점에서 CoreData 장점 활용
- 안읽은 개수는 메시지 전체 fetch 대신 `count(for:)` 배치 쿼리로 처리해 메모리 사용을 줄였습니다.
- 로컬 우선 조회 전략(CoreData 즉시 표시 + 백그라운드 API 동기화)으로 체감 응답성을 확보했습니다.

## 4) 실제 구현 포인트 (면접에서 말할 때 핵심)
1. **Clean Architecture 유지**
- Presentation(ViewModel)은 UseCase/Repository 프로토콜만 의존
- Data 레이어에서만 CoreData/Socket/Network 처리

2. **로컬 우선(Local-first)**
- 진입 시 로컬 메시지를 먼저 보여주고, 서버 동기화 결과를 나중에 반영

3. **실시간 업데이트 파이프라인**
- Socket 수신 시 중복 메시지 검사 -> UPSERT -> 현재 방 Subject 갱신 -> 화면 자동 반영

4. **Optimistic Update + 상태머신**
- `.sending -> .sent/.failed` 상태 전이를 CoreData에 저장해 UI와 데이터의 정합성 유지

5. **오프라인/불안정 네트워크 대응**
- 실패 메시지 큐 기반 재전송 및 재연결 감지 후 자동 복구

6. **읽지 않음 카운트 최적화**
- `COUNT` 쿼리 기반 배치 처리로 목록 화면 성능 유지

## 5) 면접 답변 예시 (60초)
"이전에는 Realm으로 1:1 채팅을 구현하면서 라이브 업데이트의 개발 편의성을 많이 봤습니다. 이번 프로젝트는 장기 유지보수와 iOS 생태계 정합성을 우선해서 CoreData를 선택했습니다. 다만 Realm에서 체감했던 실시간 반영 경험은 포기하지 않기 위해, CoreData 변경을 Repository의 Combine Subject로 전파하는 구조를 만들었습니다. 메시지 전송은 Optimistic Update로 먼저 `.sending` 상태를 저장하고, 성공 시 `.sent`, 실패 시 `.failed`로 전이해 재시도 UX까지 처리했습니다. 또한 채팅방-메시지 relationship을 저장 전에 보장해 무결성 문제를 방지했고, 안읽은 카운트는 `count(for:)` 배치 쿼리로 최적화했습니다. 결과적으로 CoreData의 복잡도는 레이어로 캡슐화하고, 사용자 경험은 실시간성과 안정성을 같이 가져가는 방향으로 구현했습니다."

## 6) 꼬리 질문 대응

### Q1. FRC를 왜 안 썼나요?
- 현재 채팅 화면은 날짜 separator 삽입, 표시 규칙 계산, 실패 상태 처리 등 화면 가공 로직이 많아서, FRC 이벤트를 직접 UI에 매핑하기보다 `도메인 배열 -> ViewItem 재구성` 방식이 명확했습니다.
- 향후 대용량/부분 업데이트가 중요해지면 FRC 또는 Diffable로 확장할 수 있습니다.

### Q2. DiffableDataSource를 왜 안 썼나요?
- 메시지 상태 전이와 그룹 규칙 때문에 snapshot diff 계산보다 현재는 명시적 재구성 + reload가 복잡도를 낮췄습니다.
- 현재는 1:1 채팅 범위에서 성능 이슈가 크지 않아 트레이드오프를 수용했습니다.

### Q3. CoreData 동시성 리스크는 어떻게 관리했나요?
- CoreData 접근 경계를 Repository/CoreDataManager로 제한했고, `performAndWait`와 `@MainActor`를 사용해 컨텍스트 스레드 규칙을 지켰습니다.

## 7) 코드 근거 (핵심 위치)
- 채팅방 선저장 및 relationship 보장:
  - `/Users/suji/Desktop/Dev/SeSAC/Feelter/Feelter/Presentation/Chat/ChatRoom/ChatRoomViewModel.swift` (init)
  - `/Users/suji/Desktop/Dev/SeSAC/Feelter/Feelter/Data/Repository/ChatRepository.swift` (`ensureChatRoomExists`, `saveMessageToCoreData`)
- 실시간 반영(Subject 기반):
  - `/Users/suji/Desktop/Dev/SeSAC/Feelter/Feelter/Data/Repository/ChatRepository.swift` (`messagesSubjects`, `observeMessages`, `refreshMessagesFromCoreData`, `setupSocketMessageListener`)
  - `/Users/suji/Desktop/Dev/SeSAC/Feelter/Feelter/Presentation/Chat/ChatRoom/ChatRoomViewModel.swift` (`setupRealtimeUpdates`)
- UI 반영 방식(reloadData):
  - `/Users/suji/Desktop/Dev/SeSAC/Feelter/Feelter/Presentation/Chat/ChatRoom/ChatRoomViewController.swift` (`rebuildItems`, `messageTableView.reloadData`)
- Optimistic Update / 실패 처리:
  - `/Users/suji/Desktop/Dev/SeSAC/Feelter/Feelter/Data/Repository/ChatRepository.swift` (`sendMessage`)
- 재연결 후 재전송:
  - `/Users/suji/Desktop/Dev/SeSAC/Feelter/Feelter/Presentation/Chat/ChatRoom/ChatRoomViewModel.swift` (`setupNetworkMonitoring`, `retryFailedMessages`)
- 안읽음 count 최적화:
  - `/Users/suji/Desktop/Dev/SeSAC/Feelter/Feelter/Data/Local/CoreData/CoreDataManager.swift` (`fetchUnreadMessageCounts`, `fetchUnreadMessageCountsByMessageId`)
