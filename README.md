<img width="132" height="132" alt="Feelter" src="https://github.com/user-attachments/assets/2cb8dd96-f42f-4fe4-889c-20350ce80637" />


# Feelter

필터 제작부터 공유, 탐색, 결제, 채팅까지 하나의 흐름으로 연결한 앱입니다.

## 앱 미리보기

|<img width="200" alt="IMG_3734" src="https://github.com/user-attachments/assets/aca759ee-121a-44ee-aefe-58a5704525aa" />|<img width="200" alt="IMG_3740" src="https://github.com/user-attachments/assets/4d7d077b-cd9c-40bc-bd98-7f481b1b7e98" />|<img width="200" alt="IMG_3725" src="https://github.com/user-attachments/assets/4f97daa1-f269-4445-86db-99e07bf131b1" />|<img width="200" alt="IMG_3640" src="https://github.com/user-attachments/assets/c2a7c721-49da-437b-8ed7-a8b606f3be5b" />|
|:-:|:-:|:-:|:-:|

|구분|내용|
|:--:|:--|
|**팀 인원**|iOS 개발 1명, 백엔드 1명, 디자이너 1명|
|**기획 및 개발 기간**|2025.12.26 - 2026.01.25|
|**최소 지원 버전**|iOS 16.0+|

## 핵심 기능

- 이메일/비밀번호 + 소셜(카카오/Apple) 인증
- 필터 생성/편집 및 필터 상세 조회
- 이미지 기반 필터 적용 후 게시글 업로드
- 홈/랭킹/영상 피드 탐색
- CoreData + Socket.IO 기반 1:1 채팅
- 동영상 스트리밍(재생/자막/좋아요)
- PG 결제 및 서버 검증
- Firebase Messaging 기반 푸시 알림/딥링크 이동

## 기술 스택

|분류|기술 스택|
|:--:|:--|
|**Language**|![Swift](https://img.shields.io/badge/Swift-F05138?style=flat-square&logo=swift&logoColor=white)|
|**UI Framework**|![UIKit](https://img.shields.io/badge/UIKit-007AFF?style=flat-square&logo=apple&logoColor=white)|
|**Architecture**|![MVVM](https://img.shields.io/badge/MVVM-0A66C2?style=flat-square) ![Clean_Architecture](https://img.shields.io/badge/Clean_Architecture-111111?style=flat-square) ![Coordinator](https://img.shields.io/badge/Coordinator-6B7280?style=flat-square) ![Combine](https://img.shields.io/badge/Combine-FA7343?style=flat-square&logo=swift&logoColor=white)|
|**Database**|![CoreData](https://img.shields.io/badge/CoreData-5E5CE6?style=flat-square&logo=apple&logoColor=white)|
|**Networking**|![Alamofire](https://img.shields.io/badge/Alamofire-D92C2C?style=flat-square&logo=alamofire&logoColor=white) ![SocketIO](https://img.shields.io/badge/SocketIO-010101?style=flat-square&logo=socketdotio&logoColor=white)|
|**Image/Media**|![Kingfisher](https://img.shields.io/badge/Kingfisher-1F8B4C?style=flat-square) ![PhotosUI](https://img.shields.io/badge/PhotosUI-007AFF?style=flat-square&logo=apple&logoColor=white) ![AVFoundation](https://img.shields.io/badge/AVFoundation-007AFF?style=flat-square&logo=apple&logoColor=white)|
|**Layout**|![SnapKit](https://img.shields.io/badge/SnapKit-4F46E5?style=flat-square)|
|**Authentication**|![KakaoSDK](https://img.shields.io/badge/KakaoSDK-FFCD00?style=flat-square&logo=kakao&logoColor=black) ![Sign_in_with_Apple](https://img.shields.io/badge/Sign_in_with_Apple-000000?style=flat-square&logo=apple&logoColor=white)|
|**Payment**|![PortOne](https://img.shields.io/badge/PortOne(iamport)-5B47ED?style=flat-square)|
|**Apple Frameworks**|![MapKit](https://img.shields.io/badge/MapKit-007AFF?style=flat-square&logo=apple&logoColor=white) ![CoreLocation](https://img.shields.io/badge/CoreLocation-007AFF?style=flat-square&logo=apple&logoColor=white) ![WebKit](https://img.shields.io/badge/WebKit-007AFF?style=flat-square&logo=apple&logoColor=white)|
|**Push/Infra**|![Firebase_Messaging](https://img.shields.io/badge/Firebase_Messaging-FFCA28?style=flat-square&logo=firebase&logoColor=black)|
|**보안**|![Keychain](https://img.shields.io/badge/Keychain-007AFF?style=flat-square&logo=apple&logoColor=white)|

## 전체 구조

### Clean Architecture

```text
Presentation (ViewController / ViewModel / Coordinator)
        ↓
Domain (Entity / Usecase / RepositoryProtocol)
        ↓
Data (Repository / Network / Local(CoreData))
```

- 비즈니스 로직은 `Usecase`에서 처리
- 화면 상태/이벤트 바인딩은 `ViewModel(Input/Output)`으로 처리
- 화면 전환은 `Coordinator`에서 처리
- 네트워크/로컬 저장 구현은 `Data` 레이어에서 캡슐화

### 주요 데이터 흐름

- 채팅: `Socket.IO 실시간 반영 -> CoreData(로컬 우선 로딩) -> REST API 동기화`
- 인증: `AuthenticationInterceptor`로 토큰 자동 첨부/만료 시 갱신(401/419 대응)
- 스트리밍: `VideoList 조회 -> Stream URL 조회 -> AVPlayer 재생/자막 선택`
- 결제: 주문 생성 -> PG 결제 -> 서버 검증 -> 상태 반영

## 주요 기능

### 인증

|<img width="200" alt="AUTH_1" src="https://github.com/user-attachments/assets/e8da00a3-8211-4149-b90c-b4db22699424" />|<img width="200" alt="AUTH_2" src="https://github.com/user-attachments/assets/eb608dbc-c7e6-4af0-8772-fc093bdbb26f" />|
|:-:|:-:|

- 이메일/비밀번호 로그인 및 입력 유효성 검증
- Kakao 로그인, Sign in with Apple 지원
- Access/Refresh/User ID를 Keychain에 안전하게 저장
- 토큰 만료(401/419) 시 자동 갱신 후 요청 재시도, 실패 시 인증 상태 정리

### 홈 피드

|<img width="200" alt="IMG_3734" src="https://github.com/user-attachments/assets/a9f503cd-81c6-49e7-b229-871293a76557" />|<img width="200" alt="IMG_3737" src="https://github.com/user-attachments/assets/c50c405f-64ea-4083-9c95-e562290e25fa" />|
|:-:|:-:|

- 배너/오늘의 필터/작가/카테고리 랭킹 구성
- 좋아요 등 상호작용 반영
- 현재 위치 기반 지도 탐색 및 위치 정보 기반 콘텐츠 탐색
- 썸네일 이미지 로딩 최적화(Kingfisher)

### 필터

|<img width="200" alt="FILTER_1" src="https://github.com/user-attachments/assets/e37ff535-a903-4620-b71a-0fc4f166b051" />|<img width="200" alt="FILTER_2" src="https://github.com/user-attachments/assets/f3c5c50b-b360-45f4-8ef5-e795e8030ee2" />|
|:-:|:-:|

- 필터 생성(제목/카테고리/설명/가격/메타데이터 입력) 지원
- 필터 프리셋 구성 및 편집 플로우 제공
- 사진 선택 후 필터 적용 결과 미리보기
- 생성된 필터 저장/수정 흐름 지원

### 필터 상세/결제

|<img width="200" alt="IMG_3727" src="https://github.com/user-attachments/assets/30b57845-b613-4250-9cc1-21b1b0f57a18" />|<img width="200" alt="IMG_3730" src="https://github.com/user-attachments/assets/f3af9f64-fa41-41f7-a8ad-987af0a42903" />|
|:-:|:-:|

- 필터 상세 정보/프리셋 확인
- 주문 생성 후 PG 결제 연동
- 결제 완료 후 서버 검증 및 결과 반영

### 게시글/필터업로드

|<img width="200" alt="UPLOAD_1" src="https://github.com/user-attachments/assets/c43e8788-bc0d-493d-b8e7-ee777e8d04cc" />|<img width="200" alt="UPLOAD_2" src="https://github.com/user-attachments/assets/500ef6ef-f048-4a18-9cf9-66afc47e608f" />|
|:-:|:-:|

- 게시글 작성 시 이미지/동영상 첨부 및 업로드 지원
- Multipart 기반 미디어 업로드 플로우 적용
- 필터 적용 결과를 게시글 콘텐츠로 연계
- 위치 정보와 함께 게시글 탐색/등록 흐름 지원

### 채팅

|<img width="200" alt="IMG_3823" src="https://github.com/user-attachments/assets/c461ca4c-7b9c-4e31-9857-85b39c1465ee" />|<img width="200" alt="IMG_3818" src="https://github.com/user-attachments/assets/e745dc54-13f9-4553-8d13-99c61f0b4577" />|
|:-:|:-:|

- 오프라인 상태에서도 이전 채팅 내역 조회
- 실시간 수신(Socket.IO) + 로컬 저장(CoreData) 동시 처리
- Optimistic Update 기반 전송 상태(.sending/.sent/.failed) 반영
- 전송 실패 메시지 재시도/삭제 UX 제공

### 스트리밍

|<img width="200" alt="STREAMING_1" src="https://github.com/user-attachments/assets/aca759ee-121a-44ee-aefe-58a5704525aa" />|<img width="200" alt="STREAMING_2" src="https://github.com/user-attachments/assets/4f97daa1-f269-4445-86db-99e07bf131b1" />|
|:-:|:-:|

- 영상 목록 조회 및 커서 기반 페이징 로드
- Stream URL 조회 후 AVPlayer 기반 재생
- 재생 상태(일시정지/탐색/stalling) 및 화면 전환 처리
- 자막 선택 및 좋아요 상호작용 지원
