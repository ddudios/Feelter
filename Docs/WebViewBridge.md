# WebView Bridge 구현 가이드

## 목차
1. [개요](#개요)
2. [아키텍처](#아키텍처)
3. [핵심 개념](#핵심-개념)
4. [구현 세부사항](#구현-세부사항)
5. [트러블슈팅](#트러블슈팅)
6. [사용 예시](#사용-예시)

---

## 개요

### 목적
배너를 클릭하면 WebView를 통해 이벤트 페이지를 표시하고, JavaScript와 네이티브 앱 간 양방향 통신을 구현합니다.

### 주요 기능
- 배너 클릭 → 토큰 사전 갱신 → WebView 표시
- JavaScript → 앱: 출석 버튼 클릭 이벤트 수신
- 앱 → JavaScript: accessToken 전달
- JavaScript → 앱: 출석 완료 이벤트 + 출석 횟수 수신

---

## 아키텍처

### 전체 흐름도

```
User
  ↓ (배너 탭)
HomeViewController (BannerCell.onTap closure)
  ↓
HomeViewModel (bannerTapped publisher)
  ↓
TokenRepository (토큰 갱신)
  ↓
WebViewController (WKWebView)
  ↕ (JavaScript Bridge)
Web Page
```

### 레이어 구조

```
Presentation Layer
├── HomeViewController     # 배너 탭 이벤트 수신
├── HomeViewModel          # 비즈니스 로직 (토큰 갱신)
└── WebViewController      # WebView + JavaScript Bridge

Domain Layer
├── TokenRepositoryProtocol  # 토큰 갱신 인터페이스
└── Banner                   # 배너 엔티티

Data Layer
├── AuthRepository         # 토큰 갱신 구현
└── RefreshTokenResponseDTO # Refresh API 전용 DTO
```

---

## 핵심 개념

### 1. WKWebView 설정

**WKWebView vs UIWebView**
- UIWebView: Deprecated (iOS 12+)
- WKWebView: 최신, 성능 우수, JavaScript 통신 강력

**기본 설정**
```swift
let configuration = WKWebViewConfiguration()
let contentController = WKUserContentController()

// JavaScript 메시지 핸들러 등록
contentController.add(self, name: "click_attendance_button")
contentController.add(self, name: "complete_attendance")

configuration.userContentController = contentController

webView = WKWebView(frame: .zero, configuration: configuration)
webView.navigationDelegate = self
```

**왜 이렇게 구현했는가?**
- `WKUserContentController`: JavaScript에서 네이티브로 메시지 전달 담당
- `add(self, name:)`: 웹에서 `window.webkit.messageHandlers.[name].postMessage()`로 호출 가능
- `WKNavigationDelegate`: 페이지 로딩 상태 모니터링

---

### 2. JavaScript Bridge (WKScriptMessageHandler)

**양방향 통신 메커니즘**

#### 웹 → 앱 (WKScriptMessageHandler)
```swift
extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                              didReceive message: WKScriptMessage) {
        switch message.name {
        case "click_attendance_button":
            handleAttendanceButtonClick()
        case "complete_attendance":
            handleAttendanceComplete(message: message)
        default:
            break
        }
    }
}
```

**웹에서 호출 방법:**
```javascript
// 웹 코드
window.webkit.messageHandlers.click_attendance_button.postMessage(null);
window.webkit.messageHandlers.complete_attendance.postMessage({count: 5});
```

#### 앱 → 웹 (evaluateJavaScript)
```swift
let script = "requestAttendance('\(accessToken)')"
webView.evaluateJavaScript(script)
```

**웹에서 함수 정의:**
```javascript
// 웹 코드
function requestAttendance(token) {
    // 토큰을 사용해서 출석 API 호출
}
```

**왜 이 방식인가?**
- `WKScriptMessageHandler`: JavaScript → Swift 통신의 표준 방식
- `evaluateJavaScript`: Swift → JavaScript 통신의 표준 방식
- 타입 안전성: `message.body`로 데이터 파싱

---

### 3. 토큰 갱신 전략

**문제 정의**
- WebView에서 API 호출 시 토큰이 만료되면 "회원정보를 찾을 수 없습니다" 에러 발생
- 사용자 경험 악화

**해결책: 사전 토큰 갱신**
```swift
// HomeViewModel.swift
input.bannerTapped
    .sink { [weak self] banner in
        guard let self = self else { return }
        guard banner.linkType == .webView else { return }

        isLoadingSubject.send(true)  // 로딩 시작

        Task {
            do {
                // 1. Keychain에서 토큰 읽기
                guard let accessToken = KeychainManager.shared.read(account: "accessToken"),
                      let refreshToken = KeychainManager.shared.read(account: "refreshToken") else {
                    // 토큰 없음 → 로그아웃
                    NotificationCenter.default.post(name: .unauthorizedError, object: nil)
                    return
                }

                // 2. 토큰 갱신
                let newToken = try await self.tokenRepository.refreshToken(
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )

                // 3. 새 토큰 저장
                KeychainManager.shared.save(token: newToken.accessToken, account: "accessToken")
                KeychainManager.shared.save(token: newToken.refreshToken, account: "refreshToken")

                // 4. WebView 표시
                let fullURL = "\(Config.baseURL)\(banner.linkPath)"
                presentWebViewSubject.send(fullURL)
            } catch {
                // 갱신 실패 → 로그아웃
                KeychainManager.shared.delete(account: "accessToken")
                KeychainManager.shared.delete(account: "refreshToken")
                NotificationCenter.default.post(name: .unauthorizedError, object: nil)
            }
        }
    }
```

**왜 이렇게 구현했는가?**
- **사전 갱신**: WebView 로드 전에 토큰을 미리 갱신해서 에러 방지
- **로딩 인디케이터**: UI가 멈춘 것처럼 보이지 않게 함
- **실패 처리**: 갱신 실패 시 자동 로그아웃 (AppCoordinator가 알림 표시)

---

### 4. Closure 기반 이벤트 전달

**문제: CompositionalLayout의 orthogonalScrollingBehavior**
- 가로 스크롤 사용 시 `didSelectItemAt`이 호출되지 않음
- iOS의 알려진 이슈

**해결책: Closure + TapGestureRecognizer**

```swift
// BannerCell.swift
final class BannerCell: BaseCollectionViewCell {
    var onTap: ((Banner) -> Void)?  // ✅ Closure 방식
    private var currentBanner: Banner?

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap() {
        if let banner = currentBanner {
            onTap?(banner)  // ✅ Closure 호출
        }
    }

    func configure(with banner: Banner) {
        currentBanner = banner
        // 이미지 설정...
    }
}

// HomeViewController.swift
cell.onTap = { [weak self] tappedBanner in
    self?.bannerTappedSubject.send(tappedBanner)
}
```

**왜 Closure인가?**
- **Delegate vs Closure**:
  - Delegate: 프로토콜 정의 + 채택 필요 → 보일러플레이트 많음
  - Closure: 간결하고 직관적
- **Combine vs Closure**:
  - Combine: Cell 재사용 시 구독 관리 복잡
  - Closure: Cell 재사용과 무관하게 동작

---

## 구현 세부사항

### Protocol 분리 (ISP: Interface Segregation Principle)

**문제**
```swift
// Before
protocol AuthRepositoryProtocol {
    func login(...) async throws -> (User, AuthToken)
    func logout() async throws
    func refreshToken(...) async throws -> AuthToken  // ← HomeViewModel은 이것만 필요
}
```

HomeViewModel은 `refreshToken`만 필요한데 login, logout까지 접근 가능 → 불필요한 의존성

**해결**
```swift
// TokenRepositoryProtocol.swift (신규)
protocol TokenRepositoryProtocol {
    func refreshToken(accessToken: String, refreshToken: String) async throws -> AuthToken
}

// AuthRepositoryProtocol.swift (수정)
protocol AuthRepositoryProtocol {
    func login(email: String, password: String) async throws -> (User, AuthToken)
    func logout() async throws
}

// AuthRepository.swift
final class AuthRepository: AuthRepositoryProtocol, TokenRepositoryProtocol {
    // 두 프로토콜 모두 구현
}

// AppDI.swift
let authRepository = AuthRepository(networkManager: networkManager)
container.registerSingleton(AuthRepositoryProtocol.self, instance: authRepository)
container.registerSingleton(TokenRepositoryProtocol.self, instance: authRepository)  // 같은 인스턴스
```

**왜 분리했는가?**
- **ISP 준수**: 클라이언트는 사용하지 않는 메서드에 의존하지 않아야 함
- **명확한 의도**: HomeViewModel은 토큰 갱신만 수행한다는 것이 명확
- **테스트 용이성**: Mock 객체 작성 시 필요한 메서드만 구현

---

### AuthenticationInterceptor 순환 의존성 방지

**문제**
```swift
// 순환 의존성 발생!
APISession.shared.session (Interceptor 포함)
  ↓
AuthenticationInterceptor.retry()
  ↓
AuthRepository.refreshToken()
  ↓
NetworkManager.request()
  ↓
APISession.shared.session (Interceptor 포함)  // 🔄 순환!
```

**해결**
```swift
// AuthenticationInterceptor.swift
final class AuthenticationInterceptor: RequestInterceptor {
    // Interceptor 없는 별도 Session (순환 의존성 방지)
    private let refreshSession: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        return Session(configuration: configuration)  // ✅ Interceptor 없음!
    }()

    func retry(...) {
        Task {
            // 별도 Session 사용
            let networkManager = NetworkManager(session: refreshSession)
            let repository = AuthRepository(networkManager: networkManager)
            let newToken = try await repository.refreshToken(...)

            // 성공 시 재시도
            requestsToRetry.forEach { $0(.retry) }
        }
    }
}
```

**왜 이렇게 구현했는가?**
- **순환 방지**: refreshSession은 Interceptor가 없어서 무한 루프 방지
- **독립성**: 토큰 갱신은 별도의 네트워크 계층에서 처리

---

### DTO 분리

**문제**
```swift
// Login API 응답
{
    "user_id": "...",
    "email": "...",
    "nick": "...",
    "profileImage": "...",
    "accessToken": "...",
    "refreshToken": "..."
}

// Refresh API 응답
{
    "accessToken": "...",
    "refreshToken": "..."
}
```

하나의 `AuthResponseDTO`로 처리하면 Refresh API에서 디코딩 실패!

**해결**
```swift
// AuthResponseDTO.swift (Login 전용)
struct AuthResponseDTO: Decodable {
    let userId: String
    let email: String
    let nick: String
    let profileImage: String?
    let accessToken: String
    let refreshToken: String
}

// RefreshTokenResponseDTO.swift (Refresh 전용, 신규)
struct RefreshTokenResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
}

// AuthRepository.swift
func refreshToken(...) async throws -> AuthToken {
    let response = try await networkManager.request(
        AuthRouter.refresh(...),
        type: RefreshTokenResponseDTO.self  // ✅ Refresh 전용 DTO
    )
    return response.toToken()
}
```

**왜 분리했는가?**
- **API 응답 구조 차이**: Login과 Refresh는 다른 데이터 반환
- **타입 안전성**: 각 API에 맞는 DTO 사용
- **유지보수성**: 각 API 변경 시 영향 범위 최소화

---

### BaseViewController 생명주기 고려

**문제**
```swift
// WebViewController.swift (잘못된 순서)
override func viewDidLoad() {
    super.viewDidLoad()  // ← BaseViewController.configureHierarchy() 호출
                         //   → view.addSubview(webView) 실행
                         //   → 💥 webView가 아직 nil!
    setupWebView()       // ← 이제야 webView 생성
}
```

**해결**
```swift
override func viewDidLoad() {
    setupWebView()  // ✅ 1. webView 생성
    super.viewDidLoad()  // ✅ 2. BaseViewController 호출 (configureHierarchy에서 webView 사용)
    configureNavigation()
    loadWebPage()
}
```

**왜 이 순서인가?**
- `super.viewDidLoad()`가 `configureHierarchy()`를 호출
- `configureHierarchy()`에서 `webView`를 사용
- 따라서 `super` 호출 전에 `webView` 생성 필수

---

## 트러블슈팅

### 1. 배너 이미지가 안 보이는 문제

**증상**
- 배너 API는 200 응답
- 페이지 인디케이터는 "1 / 4" 표시
- 이미지는 보이지 않음

**원인**
```swift
// UIImageView+Extension.swift
func setFeelterImage(with path: String?) {
    let fullPath = "\(Config.baseURL)v1\(path)"  // ← path 전용
}

// BannerCell.swift (잘못된 사용)
bannerImageView.setFeelterImage(with: banner.imageURL)  // ← full URL인데 path 함수 사용!
```

서버는 full URL 반환: `http://filter.sesac.kr:41598/images/banner1.png`
결과: `http://baseURL/v1/http://imageURL` ❌

**해결**
```swift
// BannerCell.swift
func configure(with banner: Banner) {
    guard let url = URL(string: banner.imageURL) else { return }
    bannerImageView.kf.setImage(with: url)  // ✅ Kingfisher로 full URL 직접 로드
}
```

---

### 2. 배너 탭 반응 없음

**증상**
- 배너를 탭해도 `didSelectItemAt` 호출 안 됨
- 로그 출력 없음

**원인**
```swift
// HomeViewController.swift
let section = NSCollectionLayoutSection(group: group)
section.orthogonalScrollingBehavior = .groupPaging  // ← 가로 스크롤 + 탭 충돌!
```

`orthogonalScrollingBehavior` 사용 시 `didSelectItemAt`이 호출되지 않는 iOS 이슈

**해결**
- BannerCell에 `UITapGestureRecognizer` 추가
- Closure로 이벤트 전달

---

### 3. 토큰 갱신 API 디코딩 실패

**증상**
```
✅ [200] http://.../auth/refresh
❌ 디코딩 에러: "The data couldn't be read because it is missing."
```

**원인**
- Refresh API는 User 정보 없이 토큰만 반환
- `AuthResponseDTO`는 User 정보 필요 → 디코딩 실패

**해결**
- `RefreshTokenResponseDTO` 신규 생성 (토큰만 포함)
- `AuthRepository.refreshToken()`에서 새 DTO 사용

---

### 4. WebViewController 크래시

**증상**
```
Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional value
Line 48: WebViewController.swift
```

**원인**
- `super.viewDidLoad()` → `configureHierarchy()` → `view.addSubview(webView!)`
- 이 시점에 `webView`가 아직 nil

**해결**
- `setupWebView()`를 `super.viewDidLoad()` **전에** 호출

---

## 사용 예시

### 1. 배너 클릭 → WebView 표시

```swift
// 1. 사용자가 배너 탭
// 2. BannerCell.handleTap() → onTap?(banner)
// 3. HomeViewController에서 bannerTappedSubject.send(banner)
// 4. HomeViewModel에서 토큰 갱신
// 5. 성공 시 presentWebViewSubject.send(fullURL)
// 6. HomeViewController에서 WebViewController present
```

### 2. 출석 이벤트 흐름

```swift
// Web Page
┌─────────────────────────────────┐
│   [출석하기] 버튼 클릭            │
│   ↓                              │
│   window.webkit.messageHandlers │
│     .click_attendance_button    │
│     .postMessage(null)          │
└─────────────────────────────────┘
            ↓
┌─────────────────────────────────┐
│ WebViewController               │
│  handleAttendanceButtonClick()  │
│   ↓                              │
│  accessToken 읽기                │
│   ↓                              │
│  evaluateJavaScript(             │
│    "requestAttendance(token)"   │
│  )                              │
└─────────────────────────────────┘
            ↓
┌─────────────────────────────────┐
│ Web Page                        │
│  function requestAttendance(t)  │
│   ↓                              │
│  서버에 출석 API 호출             │
│   ↓                              │
│  성공 시                         │
│   window.webkit.messageHandlers │
│     .complete_attendance        │
│     .postMessage({count: 5})    │
└─────────────────────────────────┘
            ↓
┌─────────────────────────────────┐
│ WebViewController               │
│  handleAttendanceComplete()     │
│   ↓                              │
│  출석 횟수 파싱                   │
│   ↓                              │
│  "출석이 완료되었습니다!         │
│   (총 5회)" 알림 표시            │
└─────────────────────────────────┘
```

---

## 참고 자료

- [WKWebView - Apple Developer](https://developer.apple.com/documentation/webkit/wkwebview)
- [WKScriptMessageHandler - Apple Developer](https://developer.apple.com/documentation/webkit/wkscriptmessagehandler)
- [Interface Segregation Principle](https://en.wikipedia.org/wiki/Interface_segregation_principle)
