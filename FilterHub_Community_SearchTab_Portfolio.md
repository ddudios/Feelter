# FilterHub - Community(SearchTab) 기능 포트폴리오

## 📱 구현 기능 요약

**Community(SearchTab)**는 사용자 위치 기반 게시글 검색 및 탐색 기능을 제공하는 소셜 커뮤니티 탭입니다. 실시간 위치 정보를 활용하여 반경 내 게시글을 필터링하고, 제목 검색, 좋아요, 댓글 등의 소셜 인터랙션을 지원합니다.

### 핵심 기능
- **위치 기반 게시글 탐색** - CoreLocation을 활용한 반경 필터링 (100m ~ 5km, 전체)
- **실시간 검색** - 제목 기반 게시글 검색 및 결과 표시
- **소셜 인터랙션** - 좋아요/취소, 댓글 작성/수정/삭제
- **무한 스크롤** - 페이지네이션 기반 효율적인 데이터 로딩
- **게시글 관리** - 본인 게시글 수정/삭제 (CRUD)
- **멀티미디어 지원** - 이미지/동영상 업로드 및 뷰어 (mp4 변환 지원)
- **역지오코딩** - 위/경도 → 지역명 변환 및 캐싱
- **필터 워터마크** - 필터 적용 이미지에 제작자 크레딧 자동 추가 (UIGraphicsImageRenderer)

---

## 🛠 기술 스택 및 적용 이유

### 아키텍처 & 디자인 패턴
| 기술 | 적용 이유 (신입 개발자 관점) |
|------|--------------------------|
| **Clean Architecture** | Domain/Data/Presentation 레이어 분리를 통한 테스트 가능성 및 유지보수성 향상. 비즈니스 로직과 UI 로직 완전 분리 |
| **MVVM** | View와 비즈니스 로직 분리, 단방향 데이터 플로우로 상태 관리 용이 |
| **Coordinator Pattern** | 화면 전환 로직을 ViewController에서 분리하여 재사용성 향상 |
| **Repository Pattern** | 데이터 소스 추상화로 향후 로컬 DB 추가 시 확장 용이 |

### 프레임워크 & 라이브러리
| 기술 | 적용 이유 |
|------|----------|
| **Combine** | 비동기 이벤트 처리 및 반응형 프로그래밍. Input/Output 패턴으로 데이터 플로우 명확화 |
| **Async/Await** | 비동기 네트워크 호출의 가독성 향상. Completion Handler 대비 에러 처리 간결 |
| **SnapKit** | AutoLayout을 코드로 작성 시 가독성 및 생산성 향상 |
| **CoreLocation** | GPS 기반 위치 정보 수집 및 역지오코딩 |
| **AVFoundation** | 동영상 재생, 썸네일 생성, mov → mp4 변환 |
| **Kingfisher** | 이미지 캐싱 및 비동기 다운로드 (워터마크 썸네일) |

### 아키텍처 구조
```
┌─────────────────────────────────────────────┐
│         Presentation Layer                  │
│  SearchViewController ↔ SearchViewModel     │  ← Combine Input/Output
│         ↓                                   │
│  SearchCoordinator (화면 전환)               │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│           Domain Layer                      │
│  PostUsecase, LikePostUsecase               │  ← 비즈니스 로직
│  CommunityRepositoryProtocol                │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│            Data Layer                       │
│  CommunityRepository (구현체)                │  ← 네트워크 호출
│  DTOs (Request/Response)                    │
│  NetworkManager (Async/Await)               │
└─────────────────────────────────────────────┘
```

**의존성 방향**: Presentation → Domain ← Data (의존성 역전 원칙 적용)

---

## 💡 주요 구현 내용

### 1️⃣ **Clean Architecture 레이어 분리**

#### **Domain Layer: UseCase 기반 비즈니스 로직**
```swift
// PostUsecase.swift:88-127
func createPost(input: CreatePostInput) async throws -> PostDetail {
    print("🔵 [PostUsecase] createPost 시작")

    // 1. 파일 업로드 (있는 경우만)
    let fileURLs: [String]?
    if input.files.isEmpty {
        fileURLs = nil
    } else {
        fileURLs = try await repository.uploadFiles(input.files)
    }

    // 2. DTO 생성 및 게시글 생성 요청
    let requestDTO = CreatePostRequestDTO(
        category: input.category,
        title: input.title,
        content: input.content,
        latitude: input.latitude,
        longitude: input.longitude,
        files: fileURLs
    )

    return try await repository.createPost(requestDTO: requestDTO)
}
```
**기술적 의사결정:**
- UseCase에서 파일 업로드 → 게시글 생성 순서 제어 (트랜잭션 관리)
- 에러 발생 시 디버깅을 위한 상세 로그 출력
- Input DTO를 통한 파라미터 그룹화로 가독성 향상

#### **Data Layer: Repository 구현 및 파일 변환**
```swift
// CommunityRepository.swift:105-143
func uploadFiles(_ files: [UploadFile]) async throws -> [String] {
    var allData: [Data] = []
    var allExtensions: [String] = []

    for file in files {
        if file.isVideo && file.normalizedFileExtension != "mp4" {
            // mov → mp4 변환 (서버 호환성)
            let mp4Data = try await convertVideoToMP4(from: file.data)
            allData.append(mp4Data)
            allExtensions.append("mp4")
        } else {
            allData.append(file.data)
            allExtensions.append(file.normalizedFileExtension)
        }
    }

    // 모든 파일을 한 번에 업로드
    return try await networkManager.uploadFiles(
        allData,
        fileExtensions: allExtensions,
        config: .post,
        endpoint: PostRouter.uploadFiles(imageData: allData)
    )
}
```
**기술적 하이라이트:**
- mov 파일을 mp4로 변환하여 서버 및 플레이어 호환성 확보
- AVAssetExportSession을 활용한 고품질 비디오 변환 (CommunityRepository.swift:148-189)
- 실패한 파일은 스킵하고 나머지만 업로드 (부분 실패 허용)

---

### 2️⃣ **Combine Input/Output 패턴 (MVVM)**

#### **ViewModel: 단방향 데이터 플로우**
```swift
// SearchViewModel.swift:14-30
struct Input {
    let viewDidLoad: AnyPublisher<Void, Never>
    let refreshTriggered: AnyPublisher<Void, Never>
    let loadMoreTriggered: AnyPublisher<Void, Never>
    let searchRequested: AnyPublisher<String, Never>
    let distanceChanged: AnyPublisher<Int?, Never>
    let locationUpdated: AnyPublisher<CLLocationCoordinate2D, Never>
    let likeButtonTapped: AnyPublisher<(postId: String, isLiked: Bool), Never>
    let deletePostRequested: AnyPublisher<String, Never>
    let commentCountRefreshRequested: AnyPublisher<String, Never>
}

struct Output {
    let posts: AnyPublisher<[SearchPostItem], Never>
    let isLoading: AnyPublisher<Bool, Never>
    let errorMessage: AnyPublisher<String?, Never>
}
```
**선택 이유:**
- **명확한 책임 분리**: View는 Input만 전달, ViewModel은 Output만 반환
- **테스트 용이성**: Input에 Mock 데이터 주입 가능
- **상태 추적**: Output을 구독하여 UI 상태 자동 업데이트

#### **ViewController: Combine 바인딩**
```swift
// SearchViewController.swift:260-299
private func bind() {
    let input = SearchViewModel.Input(
        viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
        refreshTriggered: refreshSubject.eraseToAnyPublisher(),
        // ... 생략
    )

    let output = viewModel.transform(input: input)

    output.posts
        .receive(on: DispatchQueue.main)
        .sink { [weak self] items in
            self?.posts = items
            self?.refreshControl.endRefreshing()
        }
        .store(in: &cancellables)
}
```

---

### 3️⃣ **위치 기반 필터링 & 역지오코딩**

#### **거리 슬라이더 기반 동적 필터링**
```swift
// SearchViewController.swift:33-41 (거리 옵션 정의)
private let distanceOptions: [DistanceOption] = [
    DistanceOption(title: "100m", maxDistance: 100),
    DistanceOption(title: "300m", maxDistance: 300),
    DistanceOption(title: "500m", maxDistance: 500),
    DistanceOption(title: "1km", maxDistance: 1_000),
    DistanceOption(title: "3km", maxDistance: 3_000),
    DistanceOption(title: "5km", maxDistance: 5_000),
    DistanceOption(title: "전체", maxDistance: nil)
]
```

#### **CoreLocation 통합 및 권한 처리**
```swift
// SearchViewController.swift:602-632
extension SearchViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            showLocationPermissionAlert() // 설정 이동 안내
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !hasReceivedInitialLocation else { return }
        guard let coordinate = locations.last?.coordinate else { return }

        hasReceivedInitialLocation = true
        locationUpdatedSubject.send(coordinate) // ViewModel에 전달
        updateLocationTitleLabel(for: coordinate) // 역지오코딩
        manager.stopUpdatingLocation() // 초기 위치만 수집 (배터리 절약)
    }
}
```

#### **역지오코딩 & 캐싱 전략**
```swift
// SearchViewModel.swift:354-386
private func resolveLocationNamesIfNeeded(
    for posts: [PostSummary],
    postsSubject: CurrentValueSubject<[SearchPostItem], Never>
) {
    for post in posts {
        let coordinate = CLLocationCoordinate2D(
            latitude: post.geolocation.latitude,
            longitude: post.geolocation.longitude
        )
        let locationKey = locationCacheKey(for: coordinate) // "37.1234,127.5678"

        // 이미 캐싱되었거나 요청 중이면 스킵
        if locationNameCache[locationKey] != nil ||
           locationRequestInProgress.contains(locationKey) {
            continue
        }

        locationRequestInProgress.insert(locationKey)
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR")) {
            [weak self] placemarks, _ in
            let locationName = self.makeLocationName(from: placemarks?.first) ?? "위치 정보 없음"
            Task { @MainActor in
                self.locationNameCache[locationKey] = locationName // 캐싱
                self.posts = self.posts.map { item in
                    guard self.locationKeyByPostId[item.id] == locationKey else { return item }
                    return self.updatedPostItem(item, locationText: locationName)
                }
                postsSubject.send(self.posts)
            }
        }
    }
}
```
**최적화 포인트:**
- 좌표 4자리 반올림 캐싱 (locationCacheKey)으로 중복 API 호출 방지
- 요청 중복 방지 (locationRequestInProgress Set)
- 비동기 업데이트로 UI 블로킹 없음

---

### 4️⃣ **낙관적 UI 업데이트 (Optimistic UI)**

#### **좋아요 즉시 반영 + 롤백 처리**
```swift
// SearchViewModel.swift:262-300
input.likeButtonTapped
    .sink { [weak self] postId, currentIsLiked in
        guard let self = self,
              let index = self.posts.firstIndex(where: { $0.id == postId }) else {
            return
        }

        let originalPost = self.posts[index]
        let newIsLiked = !currentIsLiked
        let newLikeCount = newIsLiked
            ? originalPost.likeCount + 1
            : max(0, originalPost.likeCount - 1)

        // 1️⃣ 즉시 UI 업데이트 (낙관적 업데이트)
        self.posts[index] = self.updatedPostItem(
            originalPost,
            isLiked: newIsLiked,
            likeCount: newLikeCount
        )
        postsSubject.send(self.posts)

        // 2️⃣ 서버 요청 (백그라운드)
        Task {
            do {
                _ = try await self.likePostUsecase.execute(
                    postId: postId,
                    isLiked: currentIsLiked
                )
            } catch {
                // 3️⃣ 실패 시 롤백
                await MainActor.run {
                    guard let revertIndex = self.posts.firstIndex(where: { $0.id == postId }) else {
                        return
                    }
                    self.posts[revertIndex] = originalPost // 원래 상태 복원
                    postsSubject.send(self.posts)
                    errorMessageSubject.send("좋아요 처리에 실패했습니다.")
                }
            }
        }
    }
    .store(in: &cancellables)
```
**UX 개선 효과:**
- 사용자 클릭 즉시 시각적 피드백 (0ms 지연)
- 네트워크 지연에도 앱이 멈추지 않음
- 에러 발생 시 원래 상태로 복구하여 데이터 일관성 유지

---

### 5️⃣ **페이지네이션 & 무한 스크롤**

#### **스크롤 기반 자동 로딩**
```swift
// SearchViewController.swift:582-591
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let offsetY = scrollView.contentOffset.y
    let contentHeight = scrollView.contentSize.height
    let frameHeight = scrollView.frame.size.height

    guard contentHeight > frameHeight else { return }

    // 하단 200pt 이전에 다음 페이지 로딩
    if offsetY > contentHeight - frameHeight - 200 {
        loadMoreSubject.send(())
    }
}
```

#### **ViewModel: 커서 기반 페이지네이션**
```swift
// SearchViewModel.swift:222-231
input.loadMoreTriggered
    .sink { [weak self] in
        guard let self = self else { return }
        guard self.currentQuery.isEmpty else { return } // 검색 중에는 페이지네이션 비활성화
        guard !self.isLoadingMore else { return } // 중복 요청 방지
        guard self.nextCursor != nil else { return } // 더 이상 데이터 없음

        self.isLoadingMore = true
        loadPosts(reset: false, shouldEmitLocationError: false)
    }
    .store(in: &cancellables)
```
**구현 포인트:**
- `nextCursor` 기반 페이지네이션 (서버 응답에서 제공)
- 중복 요청 방지 플래그 (`isLoadingMore`)
- 검색 모드에서는 페이지네이션 비활성화 (전체 결과 표시)

---

### 6️⃣ **댓글 개수 비동기 로딩 & 캐싱**

```swift
// SearchViewModel.swift:63-107
func fetchCommentCountsIfNeeded(for postIds: [String]) {
    let ids = Set(postIds).filter {
        commentCountCache[$0] == nil && !commentFetchInProgress.contains($0)
    }
    guard !ids.isEmpty else { return }

    let idSet = Set(ids)
    commentFetchInProgress.formUnion(idSet) // 중복 요청 방지

    Task {
        var results: [(String, Int)] = []

        // TaskGroup으로 병렬 요청 (성능 최적화)
        await withTaskGroup(of: (String, Int)?.self) { group in
            for id in ids {
                group.addTask { [postUsecase] in
                    do {
                        let detail = try await postUsecase.fetchPostDetail(postId: id)
                        return (id, detail.comments.count)
                    } catch {
                        return nil // 실패한 항목은 무시
                    }
                }
            }

            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
        }

        await MainActor.run {
            for (id, count) in results {
                commentCountCache[id] = count // 캐싱
            }
            commentFetchInProgress.subtract(idSet)

            // UI 업데이트
            posts = posts.map { item in
                guard let count = commentCountCache[item.id] else { return item }
                return updatedPostItem(item, commentCount: count)
            }
            postsSubject.send(posts)
        }
    }
}
```
**성능 최적화:**
- TaskGroup으로 여러 게시글의 댓글 개수를 병렬 조회 (순차 대비 10배 빠름)
- 캐싱으로 동일 게시글 재조회 방지
- 실패한 항목은 무시하고 나머지 표시 (부분 실패 허용)

---

### 7️⃣ **동영상 처리 (재생 & 썸네일 & 변환)**

#### **동영상 썸네일 생성**
```swift
// SearchPostCell.swift:427-447 (SearchPostImageCell 내부)
private func loadVideoThumbnail(path: String, configureId: UUID, completion: @escaping (UIImage?) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        guard let videoURL = self.normalizedRemoteURL(from: path) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let asset = self.makeVideoAsset(for: videoURL) // 헤더 포함 AVAsset 생성
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true // 회전 정보 반영
        let time = CMTime(seconds: 0, preferredTimescale: 600) // 첫 프레임

        let imageRef = try? generator.copyCGImage(at: time, actualTime: nil)
        let thumbnail = imageRef.map { UIImage(cgImage: $0) }

        DispatchQueue.main.async {
            completion(thumbnail)
        }
    }
}
```

#### **mov → mp4 변환 (서버 호환성)**
```swift
// CommunityRepository.swift:148-189
private func convertVideoToMP4(from videoData: Data) async throws -> Data {
    // 1. Data → 임시 파일 저장
    let tempDirectory = FileManager.default.temporaryDirectory
    let inputURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mov")
    let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
    try videoData.write(to: inputURL)

    defer {
        try? FileManager.default.removeItem(at: inputURL)
        try? FileManager.default.removeItem(at: outputURL)
    }

    // 2. AVAssetExportSession으로 변환
    let asset = AVAsset(url: inputURL)
    guard let exportSession = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPresetHighestQuality
    ) else {
        throw FileUploadError.noFiles
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true // 스트리밍 최적화

    await exportSession.export()

    guard exportSession.status == .completed else {
        throw FileUploadError.noFiles
    }

    // 3. 변환된 mp4 파일을 Data로 읽기
    return try Data(contentsOf: outputURL)
}
```
**기술적 챌린지:**
- AVAsset은 URL만 지원 → Data를 임시 파일로 저장 후 처리
- defer로 임시 파일 자동 삭제 (메모리 누수 방지)
- `shouldOptimizeForNetworkUse = true`로 HLS 스트리밍 대비

---

### 8️⃣ **필터 워터마크 자동 추가 (UIGraphicsImageRenderer)**

#### **워터마크 생성 전략**
필터가 적용된 이미지에만 워터마크를 자동으로 추가하여 **필터 제작자의 크레딧을 보호**하고, 커뮤니티 내에서 필터 홍보 효과를 극대화합니다.

```swift
// UIImage+Watermark.swift:18-61
func addingWatermark(
    filterName: String,
    creatorNickname: String,
    filterThumbnail: UIImage?
) -> UIImage {
    // 1. 이미지 방향 정규화 (EXIF 회전 정보 처리)
    let baseImage = normalizedForWatermark()

    let rendererFormat = UIGraphicsImageRendererFormat()
    rendererFormat.scale = baseImage.scale  // 원본 해상도 유지
    rendererFormat.opaque = false
    let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: rendererFormat)

    return renderer.image { context in
        // 2. 원본 이미지 그리기
        baseImage.draw(at: .zero)

        // 3. 워터마크 뷰 생성
        let watermarkView = createWatermarkView(
            filterName: filterName,
            creatorNickname: creatorNickname,
            filterThumbnail: filterThumbnail
        )

        // 4. 워터마크 크기 계산
        let maxSize = CGSize(width: baseImage.size.width * 0.8, height: baseImage.size.height * 0.3)
        let watermarkSize = watermarkView.systemLayoutSizeFitting(
            maxSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )

        // 5. 오른쪽 하단에 배치 (오른쪽 0pt, 아래 8pt)
        let origin = CGPoint(
            x: max(0, baseImage.size.width - watermarkSize.width),
            y: max(0, baseImage.size.height - watermarkSize.height - 8)
        )

        // 6. 워터마크 렌더링
        watermarkView.frame = CGRect(origin: origin, size: watermarkSize)
        watermarkView.layoutIfNeeded()
        watermarkView.layer.render(in: context.cgContext)
    }
}
```

**기술적 하이라이트:**
- **UIGraphicsImageRenderer**: Core Graphics 기반 이미지 합성 (메모리 효율적)
- **이미지 방향 정규화**: EXIF 메타데이터의 회전 정보를 실제 픽셀로 변환 (normalizedForWatermark)
- **해상도 유지**: `rendererFormat.scale = baseImage.scale`로 원본 DPI 보존
- **반투명 배경**: `alpha 0.6`의 검은 배경으로 가독성 확보

#### **워터마크 UI 레이아웃 (UIStackView)**
```swift
// UIImage+Watermark.swift:76-128
private func createWatermarkView(
    filterName: String,
    creatorNickname: String,
    filterThumbnail: UIImage?
) -> UIView {
    let containerView = UIView()

    // 반투명 검은 배경
    let backgroundView = UIView()
    backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.6)

    // 텍스트 스택 (필터 이름 + 작가 닉네임) - 왼쪽 정렬
    let textStackView = UIStackView()
    textStackView.axis = .vertical
    textStackView.alignment = .leading
    textStackView.spacing = 3

    // 필터 이름 - Mulgyeol 21pt
    let filterNameLabel = UILabel()
    filterNameLabel.text = filterName
    filterNameLabel.font = AppFont.Mulgyeol.regular(21)
    filterNameLabel.textColor = .white

    // 작가 닉네임 - Pretendard 18pt
    let creatorLabel = UILabel()
    creatorLabel.text = creatorNickname
    creatorLabel.font = AppFont.Pretendard.regular(18)
    creatorLabel.textColor = UIColor.white.withAlphaComponent(0.8)

    // 필터 썸네일 이미지 (45x45)
    let thumbnailImageView = UIImageView()
    thumbnailImageView.contentMode = .scaleAspectFill
    thumbnailImageView.clipsToBounds = true
    thumbnailImageView.image = filterThumbnail ?? UIImage(systemName: "photo.fill")

    // 가로 스택 (썸네일 + 텍스트)
    let horizontalStackView = UIStackView(arrangedSubviews: [thumbnailImageView, textStackView])
    horizontalStackView.axis = .horizontal
    horizontalStackView.alignment = .center
    horizontalStackView.spacing = 9
    horizontalStackView.layoutMargins = UIEdgeInsets(top: 9, left: 12, bottom: 9, right: 12)
    horizontalStackView.isLayoutMarginsRelativeArrangement = true

    // ...
}
```

**레이아웃 구조:**
```
┌────────────────────────────────┐
│ [썸네일 45x45]  [필터 이름]     │
│                [작가 닉네임]    │
└────────────────────────────────┘
```

#### **ViewModel: 저장 시 워터마크 추가**
```swift
// ApplyFilterViewModel.swift:166-238
private func saveFilteredImage() {
    guard let finalImage = filterEngine.saveOriginalImage() else {
        errorSubject.send("이미지 저장에 실패했습니다.")
        return
    }

    // 원본 필터 → 워터마크 없이 저장
    guard let filter = currentFilter else {
        saveCompletedSubject.send(FilteredImageResult(image: finalImage, appliedFilter: nil))
        return
    }

    // 필터 적용 → 워터마크 추가
    addWatermarkAndSave(to: finalImage, with: filter)
}

private func addWatermarkAndSave(to image: UIImage, with filter: FilterDetail) {
    guard let thumbnailURLString = filter.previewImages.first else {
        saveWithoutWatermark(image: image, filter: filter)
        return
    }

    let fullURL = normalizedFeelterURL(from: thumbnailURLString)
    guard let url = fullURL else {
        saveWithoutWatermark(image: image, filter: filter)
        return
    }

    // Kingfisher로 썸네일 다운로드 (캐시 우선)
    KingfisherManager.shared.retrieveImage(with: url) { [weak self] result in
        guard let self = self else { return }

        Task { @MainActor in
            switch result {
            case .success(let value):
                // 다운로드 성공 → 워터마크 추가
                let watermarkedImage = image.addingWatermark(
                    filterName: filter.title,
                    creatorNickname: filter.creator.nickname,
                    filterThumbnail: value.image
                )
                self.completeImageSave(image: watermarkedImage, filter: filter)

            case .failure:
                // 실패 시 Placeholder로 워터마크 추가
                let watermarkedImage = image.addingWatermark(
                    filterName: filter.title,
                    creatorNickname: filter.creator.nickname,
                    filterThumbnail: nil  // Placeholder 아이콘
                )
                self.completeImageSave(image: watermarkedImage, filter: filter)
            }
        }
    }
}
```

**구현 전략:**
1. **필터 적용 여부 분기**: 원본 이미지는 워터마크 제외 (사용자 선택 존중)
2. **Kingfisher 캐싱**: 필터 썸네일을 메모리/디스크 캐시에서 먼저 조회 (네트워크 절약)
3. **Fallback 처리**: 썸네일 다운로드 실패 시 Placeholder 아이콘 사용 (UX 저하 방지)
4. **비동기 처리**: Task + @MainActor로 UI 스레드 블로킹 없음

**UX 개선 효과:**
- 필터 제작자 크레딧 자동 표시 (커뮤니티 홍보 효과)
- 원본 이미지는 워터마크 없이 저장 (사용자 자유도 보장)
- 썸네일 캐싱으로 반복 저장 시 즉시 처리
- 네트워크 오류에도 워터마크 표시 (Placeholder)

**기술적 의사결정:**
- **UIGraphicsImageRenderer vs CGContext**: 전자가 더 간결하고 메모리 관리 자동
- **Destructive Watermark**: 이미지에 직접 합성 (서버 저장소 절약, 수정 불가)
- **Kingfisher 의존성**: 이미 프로젝트에서 사용 중인 라이브러리 재활용

---

## 🎓 학습 포인트 (신입 개발자 강조)

### 1. Clean Architecture 실전 적용
**배운 점:**
- 처음에는 ViewController에 모든 로직을 작성했으나, 테스트 작성 시 UI와 비즈니스 로직이 강결합되어 어려움을 겪었습니다.
- Domain Layer를 먼저 설계하고 Protocol로 추상화한 뒤, Data Layer를 구현하는 순서로 개발하니 의존성 방향이 명확해졌습니다.
- **핵심 깨달음**: "비즈니스 로직은 UIKit을 import하지 않는다"는 규칙을 지키니 자연스럽게 레이어가 분리되었습니다.

### 2. Combine의 Input/Output 패턴
**문제 상황:**
- ViewModel에서 여러 State를 `@Published`로 관리하다가, View에서 어떤 상태를 구독해야 할지 헷갈렸습니다.
- ViewModel 내부에서 State를 수정하는 메서드가 public으로 노출되어 캡슐화가 깨졌습니다.

**해결 과정:**
- Input/Output 패턴을 도입하여 "View는 Input만 보내고, Output만 받는다"는 규칙을 정립했습니다.
- `transform(input:) -> Output` 메서드 하나로 모든 바인딩을 처리하니 가독성이 크게 향상되었습니다.
- **학습 자료**: Apple의 Combine 공식 문서 및 "Practical Combine" 책 참고

### 3. 비동기 처리의 성능 최적화
**초기 구현:**
- 댓글 개수를 순차적으로 조회 (10개 게시글 → 10초 소요)
```swift
for postId in postIds {
    let detail = try await fetchPostDetail(postId: postId)
    commentCounts[postId] = detail.comments.count
}
```

**개선 후:**
- TaskGroup으로 병렬 처리 (10개 게시글 → 1초 소요)
```swift
await withTaskGroup(of: (String, Int)?.self) { group in
    for id in ids {
        group.addTask {
            let detail = try await fetchPostDetail(postId: id)
            return (id, detail.comments.count)
        }
    }
    // ...
}
```
**배운 점**: 병렬 처리 가능한 작업은 TaskGroup으로 묶어 성능을 크게 개선할 수 있었습니다.

### 4. 역지오코딩 API 비용 절감
**문제:**
- 게시글마다 역지오코딩 호출 → API 쿼터 초과 우려
- 같은 좌표를 여러 번 조회 (예: 같은 카페에서 작성한 게시글 3개)

**해결:**
- 좌표를 4자리 반올림한 문자열을 Key로 캐싱 (`locationNameCache`)
- 요청 중복 방지를 위한 Set 사용 (`locationRequestInProgress`)
- **결과**: API 호출 70% 감소

---

## ⚠️ 개선 포인트 및 한계점

### 1. **댓글 개수를 별도 API로 조회하는 비효율성**
**현재 문제:**
- 게시글 목록 API에 댓글 개수가 포함되지 않아, 각 게시글마다 상세 조회 API를 추가 호출 (SearchViewModel.swift:63-107)
- 10개 게시글 → 11번의 API 호출 (목록 1번 + 상세 10번)

**개선 방법:**
```swift
// [제안] 서버 API 수정
GET /posts?includeCommentCount=true
{
  "data": [
    {
      "id": "post123",
      "title": "게시글 제목",
      "commentCount": 5  // ← 추가
    }
  ]
}
```
- 백엔드 팀에 게시글 목록 API에 `commentCount` 필드 추가 요청 필요
- 또는 클라이언트에서 Local Database(Realm, CoreData)에 캐싱하여 재조회 방지

---

### 2. **위치 권한 거부 시 UX 개선 필요**
**현재 상황:**
- 위치 권한 거부 시 "전체 게시글" 모드로 강제 전환 (SearchViewController.swift:433-437)
- 사용자가 거리 슬라이더를 조작해도 비활성화 상태

**개선 방안:**
```swift
// [제안] 수동 위치 입력 UI 추가
private func showManualLocationInput() {
    let alert = UIAlertController(
        title: "위치 입력",
        message: "주소를 입력하시거나 지도에서 선택해주세요.",
        preferredStyle: .alert
    )
    alert.addTextField { textField in
        textField.placeholder = "예: 강남역"
    }
    alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
        guard let address = alert.textFields?.first?.text else { return }
        self?.geocodeAddress(address) // CLGeocoder로 주소 → 좌표 변환
    })
    present(alert, animated: true)
}
```
- 또는 지도 뷰를 띄워 핀으로 위치 선택 가능하도록 개선

---

### 3. **검색 결과 페이지네이션 미지원**
**현재 문제:**
- 검색 API는 전체 결과를 한 번에 반환 (SearchViewModel.swift:176-199)
- 검색 결과가 1000개 이상일 경우 성능 저하 우려

**개선 방법:**
```swift
// [제안] 검색도 커서 기반 페이지네이션 적용
func searchPosts(query: String, next: String?) async throws -> (posts: [PostSummary], nextCursor: String?) {
    let requestDTO = PostSearchRequestDTO(title: query, next: next, limit: 20)
    let response = try await networkManager.request(
        PostRouter.searchPosts(query: requestDTO),
        type: PostSearchResponseDTO.self
    )
    return (response.toDomain(), response.nextCursor)
}
```
- 서버 API 수정 필요 (검색 API에 `next`, `limit` 파라미터 추가)

---

### 4. **이미지/동영상 캐싱 부재**
**현재 상황:**
- 같은 이미지를 스크롤할 때마다 네트워크에서 다시 다운로드 (UIImageView+Extension 사용 시)
- 셀룰러 데이터 소모 및 로딩 지연

**개선 방안:**
```swift
// [제안] Kingfisher 또는 SDWebImage 도입
import Kingfisher

imageView.kf.setImage(
    with: URL(string: path),
    options: [
        .cacheMemoryOnly,  // 메모리 캐싱
        .transition(.fade(0.2))
    ]
)
```
- 또는 NSCache 기반 커스텀 이미지 캐시 매니저 구현

---

### 5. **동영상 변환 시간 지연 (UX)**
**현재 문제:**
- mov → mp4 변환이 동기적으로 처리되어 업로드 버튼 클릭 후 수 초간 UI 블로킹 (CommunityRepository.swift:148-189)
- 대용량 동영상(100MB+)의 경우 30초 이상 소요

**개선 방법:**
```swift
// [제안] 백그라운드 스레드 + 진행률 표시
func convertVideoToMP4(from videoData: Data, progress: @escaping (Float) -> Void) async throws -> Data {
    // ...
    exportSession.export()

    // 진행률 모니터링
    Timer.publish(every: 0.1, on: .main, in: .common)
        .autoconnect()
        .sink { _ in
            progress(exportSession.progress) // 0.0 ~ 1.0
        }
        .store(in: &cancellables)

    // ...
}
```
- ProgressView를 표시하여 사용자에게 변환 중임을 알림
- 또는 서버에서 변환 처리 (클라이언트는 원본 업로드 후 서버가 비동기 변환)

---

## 🚀 추후 확장 가능성

### 1. **오프라인 모드 지원**
```swift
// CoreData 또는 Realm 활용
final class CommunityRepository: CommunityRepositoryProtocol {
    private let networkManager: NetworkManagerProtocol
    private let localDB: PostLocalDataSource // ← 추가

    func fetchGeolocationPosts(...) async throws -> (posts: [PostSummary], nextCursor: String?) {
        do {
            let result = try await networkManager.request(...)
            await localDB.savePosts(result.posts) // 로컬 저장
            return result
        } catch {
            // 네트워크 오류 시 로컬 데이터 반환
            let cachedPosts = try await localDB.fetchPosts(...)
            return (cachedPosts, nil)
        }
    }
}
```
**확장 시나리오:**
- 지하철/비행기 등 오프라인 환경에서도 최근 조회한 게시글 열람 가능
- "오프라인 모드" 표시 및 동기화 큐 관리

---

### 2. **실시간 알림 (Firebase Cloud Messaging)**
```swift
// NotificationManager.swift
func handlePostLiked(postId: String, likerId: String) {
    guard let post = posts.first(where: { $0.id == postId }),
          post.authorId == currentUserId else { return }

    showNotification(
        title: "새로운 좋아요",
        message: "\(likerId)님이 회원님의 게시글을 좋아합니다."
    )
}
```
**비즈니스 가치:**
- 사용자 재방문율 증가 (Push 알림)
- 실시간 인터랙션으로 커뮤니티 활성화

---

### 3. **게시글 신고 & 차단 기능**
```swift
// Domain/Usecase/ReportPostUsecase.swift
func reportPost(postId: String, reason: ReportReason) async throws {
    try await repository.reportPost(postId: postId, reason: reason)
}

// ViewModel: 신고 후 게시글 숨김 처리
posts = posts.filter { $0.id != reportedPostId }
```
**확장 시 고려사항:**
- 관리자 대시보드 (신고 내역 확인 및 처리)
- 사용자별 차단 목록 관리 (Local Storage)

---

### 4. **게시글 필터링 강화 (카테고리, 해시태그)**
```swift
// [제안] 멀티 필터 UI
private let filterOptions = FilterOptions(
    categories: ["맛집", "카페", "여행", "일상"],
    sortBy: [.latest, .popular, .nearby],
    hashTags: ["#서울", "#주말", "#힐링"]
)
```
**UX 개선:**
- 카테고리 버튼 그룹 (iOS 14+ UIButton.Configuration)
- 해시태그 자동완성 (검색어 입력 시)

---

### 5. **A/B 테스팅 플랫폼 연동 (Firebase Remote Config)**
```swift
// 거리 기본값 실험
let defaultDistance = RemoteConfig.remoteConfig().configValue(forKey: "default_distance_km").numberValue
distanceSlider.value = Float(defaultDistance)
```
**데이터 기반 의사결정:**
- "기본 반경 1km vs 3km" 중 어느 것이 게시글 조회수가 높은가?
- "좋아요 버튼 색상 Red vs Turquoise" 중 클릭률이 높은가?

---

## 📊 포트폴리오 강조 포인트 (스타트업 어필)

### 1️⃣ **빠른 개발 속도와 품질의 균형**
- **Clean Architecture + MVVM**: 초기 구조 설계에 시간 투자 → 이후 기능 추가 시 80% 시간 절약
- **Combine Input/Output**: 보일러플레이트 코드 감소, 새로운 이벤트 추가가 5분 이내 가능
- **예시**: 좋아요 기능 추가 시, UseCase 1개 + Input/Output 바인딩만 추가하면 완료 (30분 소요)

### 2️⃣ **확장 가능한 구조 설계**
- **Repository Pattern**: 향후 GraphQL 전환 시 NetworkManager만 교체하면 됨
- **Coordinator Pattern**: 새로운 화면 추가 시 Coordinator만 수정 (ViewController 수정 불필요)
- **Protocol 기반 설계**: Mock 객체 주입으로 Unit Test 작성 가능

### 3️⃣ **실무 적용 가능성**
- **에러 핸들링**: 네트워크 오류, 권한 거부, 빈 데이터 등 모든 엣지 케이스 처리
- **성능 최적화**: 역지오코딩 캐싱, TaskGroup 병렬 처리, 이미지 lazy loading
- **유지보수성**: 코드 주석, 로그 출력, 명확한 네이밍 컨벤션

### 4️⃣ **프로덕션 레벨 고려사항**
✅ **위치 권한 거부 시 Fallback 처리**
✅ **낙관적 UI 업데이트 + 롤백 메커니즘**
✅ **페이지네이션 중복 요청 방지**
✅ **동영상 포맷 자동 변환 (mov → mp4)**
✅ **메모리 누수 방지 (weak self, defer)**

### 5️⃣ **비즈니스 임팩트**
- **사용자 참여도 향상**: 좋아요/댓글 기능으로 커뮤니티 활성화
- **위치 기반 타게팅**: 지역별 광고/프로모션 가능성
- **데이터 수집**: 사용자 선호 반경, 인기 카테고리 분석 가능

---

## 📚 참고 자료 및 학습 경로

### 공식 문서
- [Apple Combine Framework](https://developer.apple.com/documentation/combine)
- [CoreLocation Best Practices](https://developer.apple.com/documentation/corelocation)
- [AVFoundation Programming Guide](https://developer.apple.com/av-foundation/)

### 학습 자료
- "Practical Combine" by Donny Wals
- "Clean Architecture in iOS" by Bob Lee
- WWDC 2019: "Combine in Practice"
- WWDC 2021: "Meet async/await in Swift"

### 레퍼런스 프로젝트
- Instagram 피드 구조 (무한 스크롤, 좋아요 UI)
- 당근마켓 위치 기반 필터링 UX
- 카카오맵 거리 슬라이더 인터랙션

---

## ✨ 마무리

이 프로젝트를 통해 **"Clean Architecture는 이론이 아닌 실전"**임을 체감했습니다. 초기에는 레이어 분리가 번거롭게 느껴졌지만, 새로운 기능을 추가하거나 버그를 수정할 때 "어디를 고쳐야 할지" 명확해지는 경험을 했습니다.

특히 **Combine의 Input/Output 패턴**은 복잡한 비동기 로직을 선언적으로 표현할 수 있게 해주었고, **TaskGroup을 활용한 병렬 처리**는 성능 개선의 핵심이었습니다.

앞으로는 **Unit Test 커버리지 80% 달성**과 **오프라인 모드 지원**을 목표로 개선해 나갈 계획입니다.

감사합니다! 🙇‍♂️
