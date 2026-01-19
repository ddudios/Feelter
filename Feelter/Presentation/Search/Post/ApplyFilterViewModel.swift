//
//  ApplyFilterViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import UIKit
import Combine

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

        let result = FilteredImageResult(
            image: finalImage,
            appliedFilter: currentFilter
        )

        saveCompletedSubject.send(result)
    }
}
