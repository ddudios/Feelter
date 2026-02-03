//
//  ApplyFilterViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import UIKit
import Combine
import Kingfisher

@MainActor
final class ApplyFilterViewModel {

    // MARK: - Input & Output

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let filterSelected: AnyPublisher<FilterDetail, Never>
        let saveButtonTapped: AnyPublisher<Void, Never>
    }

    struct Output {
        let filters: AnyPublisher<[FilterDetail], Never>
        let currentFilteredImage: AnyPublisher<UIImage?, Never>
        let saveCompleted: AnyPublisher<FilteredImageResult, Never>
        let error: AnyPublisher<String?, Never>
    }

    struct FilteredImageResult {
        let image: UIImage
        let appliedFilter: FilterDetail?
    }

    // MARK: - Properties

    private let originalImage: UIImage
    private let fetchMyFiltersUsecase: FetchMyFiltersUsecase
    private let filterEngine: FilterEngine

    private let filtersSubject = CurrentValueSubject<[FilterDetail], Never>([])
    private let saveCompletedSubject = PassthroughSubject<FilteredImageResult, Never>()
    private let errorSubject = CurrentValueSubject<String?, Never>(nil)

    private var currentFilter: FilterDetail?
    private var currentUserId: String? {
        return KeychainManager.shared.read(account: "userId")
    }

    // MARK: - Initialization

    init(
        originalImage: UIImage,
        fetchMyFiltersUsecase: FetchMyFiltersUsecase
    ) {
        self.originalImage = originalImage
        self.fetchMyFiltersUsecase = fetchMyFiltersUsecase
        self.filterEngine = FilterEngine()

        // 필터 엔진에 원본 이미지 설정
        self.filterEngine.setImage(from: originalImage)
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        input.viewDidLoad
            .sink { [weak self] in
                self?.loadFilters()
            }
            .store(in: &cancellables)

        input.filterSelected
            .sink { [weak self] filter in
                self?.applyFilter(filter)
            }
            .store(in: &cancellables)

        input.saveButtonTapped
            .sink { [weak self] in
                self?.saveFilteredImage()
            }
            .store(in: &cancellables)

        return Output(
            filters: filtersSubject.eraseToAnyPublisher(),
            currentFilteredImage: filterEngine.$previewImage.eraseToAnyPublisher(),
            saveCompleted: saveCompletedSubject.eraseToAnyPublisher(),
            error: errorSubject.eraseToAnyPublisher()
        )
    }

    // MARK: - Private Methods

    private var cancellables = Set<AnyCancellable>()

    private func loadFilters() {
        guard let userId = currentUserId else {
            errorSubject.send("사용자 정보를 찾을 수 없습니다.")
            return
        }

        Task {
            do {
                let filters = try await fetchMyFiltersUsecase.execute(userId: userId)
                print("🎨 [ApplyFilterViewModel] 불러온 필터 개수: \(filters.count)")
                filters.enumerated().forEach { index, filter in
                    print("🎨 [ApplyFilterViewModel] 필터 [\(index)]: \(filter.title) (ID: \(filter.id))")
                }

                // 원본 필터 추가 (맨 앞에)
                var filtersWithOriginal = filters
                let originalFilter = FilterDetail(
                    id: "original",
                    category: .unknown,
                    title: "Original",
                    description: "원본 이미지",
                    previewImages: [],
                    price: 0,
                    creator: Creator(
                        id: "system",
                        nickname: "System",
                        name: "System",
                        introduction: "",
                        profileImageURL: nil,
                        hashTags: []
                    ),
                    metadata: .empty,
                    filterValues: nil,
                    comments: [],
                    likeCount: 0,
                    buyerCount: 0,
                    isLiked: false,
                    isDownloaded: false,
                    createdAt: Date()
                )
                filtersWithOriginal.insert(originalFilter, at: 0)

                print("🎨 [ApplyFilterViewModel] 원본 포함 총 필터 개수: \(filtersWithOriginal.count)")
                filtersSubject.send(filtersWithOriginal)
            } catch {
                print("❌ [ApplyFilterViewModel] 필터 로드 실패: \(error.localizedDescription)")
                errorSubject.send("필터 목록을 불러오는데 실패했습니다.")
            }
        }
    }

    private func applyFilter(_ filter: FilterDetail) {
        print("🎨 [ApplyFilterViewModel] 필터 적용: \(filter.title) (ID: \(filter.id))")

        // 원본 필터인지 확인
        currentFilter = filter.id == "original" ? nil : filter

        guard let filterValues = filter.filterValues else {
            // 필터 값이 없으면 기본값으로 리셋 (원본 이미지)
            print("🎨 [ApplyFilterViewModel] 원본 이미지로 리셋")
            filterEngine.filterValuesSubject.send(.default)
            return
        }

        // FilterEngine에 필터 값 전달
        print("🎨 [ApplyFilterViewModel] 필터 값 적용: \(filterValues)")
        filterEngine.filterValuesSubject.send(filterValues)
    }

    private func saveFilteredImage() {
        // FilterEngine에서 고화질 이미지 저장
        guard let finalImage = filterEngine.saveOriginalImage() else {
            errorSubject.send("이미지 저장에 실패했습니다.")
            return
        }

        // 필터가 적용되지 않은 경우 (원본) - 워터마크 없이 저장
        guard let filter = currentFilter else {
            print("💾 [ApplyFilterViewModel] 원본 이미지 저장 (워터마크 없음)")
            let result = FilteredImageResult(
                image: finalImage,
                appliedFilter: nil
            )
            saveCompletedSubject.send(result)
            return
        }

        // 필터가 적용된 경우 - 워터마크 추가
        print("💾 [ApplyFilterViewModel] 필터 적용 이미지 저장 - 워터마크 추가 중...")
        print("   필터: \(filter.title)")
        print("   작가: \(filter.creator.nickname)")

        addWatermarkAndSave(to: finalImage, with: filter)
    }

    /// 워터마크를 추가하고 저장합니다
    private func addWatermarkAndSave(to image: UIImage, with filter: FilterDetail) {
        // 1. 필터 썸네일 다운로드
        guard let thumbnailURLString = filter.previewImages.first else {
            print("⚠️ [ApplyFilterViewModel] 필터 썸네일 URL 없음 - 워터마크 없이 저장")
            saveWithoutWatermark(image: image, filter: filter)
            return
        }

        // URL 생성 (Feelter 이미지 경로 처리)
        let fullURL = normalizedFeelterURL(from: thumbnailURLString)
        guard let url = fullURL else {
            print("⚠️ [ApplyFilterViewModel] 잘못된 썸네일 URL - 워터마크 없이 저장")
            saveWithoutWatermark(image: image, filter: filter)
            return
        }

        print("📥 [ApplyFilterViewModel] 필터 썸네일 다운로드 시작: \(url)")

        // Kingfisher로 썸네일 다운로드 (캐시 우선)
        KingfisherManager.shared.retrieveImage(with: url) { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                switch result {
                case .success(let value):
                    print("✅ [ApplyFilterViewModel] 썸네일 다운로드 성공")
                    let watermarkedImage = image.addingWatermark(
                        filterName: filter.title,
                        creatorNickname: filter.creator.nickname,
                        filterThumbnail: value.image
                    )
                    self.completeImageSave(image: watermarkedImage, filter: filter)

                case .failure(let error):
                    print("❌ [ApplyFilterViewModel] 썸네일 다운로드 실패: \(error.localizedDescription)")
                    // 실패 시 Placeholder로 워터마크 추가
                    let watermarkedImage = image.addingWatermark(
                        filterName: filter.title,
                        creatorNickname: filter.creator.nickname,
                        filterThumbnail: nil
                    )
                    self.completeImageSave(image: watermarkedImage, filter: filter)
                }
            }
        }
    }

    /// 워터마크 없이 저장 (Fallback)
    private func saveWithoutWatermark(image: UIImage, filter: FilterDetail) {
        let result = FilteredImageResult(
            image: image,
            appliedFilter: filter
        )
        saveCompletedSubject.send(result)
    }

    /// 이미지 저장 완료
    private func completeImageSave(image: UIImage, filter: FilterDetail) {
        print("✅ [ApplyFilterViewModel] 워터마크 추가 완료 - 저장")
        let result = FilteredImageResult(
            image: image,
            appliedFilter: filter
        )
        saveCompletedSubject.send(result)
    }

    /// Feelter 이미지 URL 정규화 (/data/... → full URL)
    private func normalizedFeelterURL(from path: String) -> URL? {
        // 이미 전체 URL인 경우
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        // 상대 경로인 경우 baseURL 추가
        let baseURLString = Config.baseURL.absoluteString
        let cleanedBase = baseURLString.hasSuffix("/") ? String(baseURLString.dropLast()) : baseURLString

        var urlPath = path
        if urlPath.hasPrefix("/data/") {
            urlPath = "/v1" + urlPath
        } else if !urlPath.hasPrefix("/v1/") {
            urlPath = "/v1/" + urlPath
        }

        return URL(string: cleanedBase + urlPath)
    }
}
