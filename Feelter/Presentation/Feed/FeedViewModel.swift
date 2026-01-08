//
//  FeedViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation
import Combine

final class FeedViewModel: ViewModelProtocol {
    
    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let sortTypeSelected: AnyPublisher<FilterSortType, Never>
        let categorySelected: AnyPublisher<FilterCategory, Never>
        let loadMore: AnyPublisher<Void, Never>
        let likeButtonTapped: AnyPublisher<(filterId: String, isLiked: Bool), Never>
    }
    
    struct Output {
        let topRankingFilters: AnyPublisher<[FilterSummary], Never>
        let feedFilters: AnyPublisher<[FilterSummary], Never>
        let isLoading: AnyPublisher<Bool, Never>
        let errorMessage: AnyPublisher<String?, Never>
    }
    
    private let filterUsecase: FilterUsecaseProtocol
    private let communityRepository: CommunityRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private var currentSortType: FilterSortType = .popularity
    private var currentCategory: FilterCategory = .food
    private var nextCursor: String?
    private var isLoadingMore = false
    private var feedFilters: [FilterSummary] = []
    private var topRankingFilters: [FilterSummary] = []
    private let topRankingCategories: [FilterCategory] = FilterCategory.allCases.filter { $0 != .unknown }
    
    init(
        filterUsecase: FilterUsecaseProtocol,
        communityRepository: CommunityRepositoryProtocol
    ) {
        self.filterUsecase = filterUsecase
        self.communityRepository = communityRepository
    }
    
    func transform(input: Input) -> Output {
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let topRankingSubject = CurrentValueSubject<[FilterSummary], Never>([])
        let feedFiltersSubject = CurrentValueSubject<[FilterSummary], Never>([])
        let errorMessageSubject = PassthroughSubject<String?, Never>()
        
        func loadTopRankingFilters() {
            Task {
                do {
                    let filters = try await fetchTopRankingFilters(
                        orderBy: currentSortType,
                        categories: topRankingCategories
                    )
                    await MainActor.run {
                        self.topRankingFilters = filters
                        topRankingSubject.send(filters)
                    }
                } catch {
                    await MainActor.run {
                        errorMessageSubject.send("카테고리 랭킹을 불러오는데 실패했습니다: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        func loadFeedFilters() {
            nextCursor = nil
            feedFilters = []
            isLoadingMore = false
            isLoadingSubject.send(true)
            
            let category = currentCategory
            let sortType = currentSortType
            
            Task {
                do {
                    let result = try await filterUsecase.fetchFilterList(
                        category: category,
                        orderBy: sortType,
                        next: nil,
                        limit: "10"
                    )
                    
                    let firstFilter = result.filters.first
                    let trimmedFilters = Array(result.filters.dropFirst())
                    
                    await MainActor.run {
                        self.feedFilters = trimmedFilters
                        self.nextCursor = result.nextCursor
                        isLoadingSubject.send(false)
                        feedFiltersSubject.send(self.feedFilters)

                        if let firstFilter,
                           let index = self.topRankingFilters.firstIndex(where: { $0.category == category }) {
                            self.topRankingFilters[index] = firstFilter
                            topRankingSubject.send(self.topRankingFilters)
                        }
                    }
                } catch {
                    await MainActor.run {
                        isLoadingSubject.send(false)
                        errorMessageSubject.send("필터 목록을 불러오는데 실패했습니다: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        input.viewDidLoad
            .sink {
                loadTopRankingFilters()
                loadFeedFilters()
            }
            .store(in: &cancellables)
        
        input.sortTypeSelected
            .sink { [weak self] sortType in
                guard let self = self else { return }
                self.currentSortType = sortType
                loadTopRankingFilters()
                loadFeedFilters()
            }
            .store(in: &cancellables)
        
        input.categorySelected
            .removeDuplicates()
            .sink { [weak self] category in
                guard let self = self else { return }
                self.currentCategory = category
                loadFeedFilters()
            }
            .store(in: &cancellables)
        
        // 무한 스크롤 (중복 호출 방지를 위한 throttle)
        input.loadMore
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: false)
            .sink { [weak self] in
                guard let self = self else { return }
                guard !self.isLoadingMore, let cursor = self.nextCursor else { return }
                
                self.isLoadingMore = true
                isLoadingSubject.send(true)
                
                Task {
                    do {
                        let result = try await self.filterUsecase.fetchFilterList(
                            category: self.currentCategory,
                            orderBy: self.currentSortType,
                            next: cursor,
                            limit: "10"
                        )
                        
                        await MainActor.run {
                            // 중복 제거: 기존에 없는 필터만 추가
                            let existingIds = Set(self.feedFilters.map { $0.id })
                            let newFilters = result.filters.filter { !existingIds.contains($0.id) }
                            
                            self.feedFilters.append(contentsOf: newFilters)
                            
                            // nextCursor가 현재와 같으면 더 이상 데이터가 없는 것으로 간주
                            if result.nextCursor == cursor {
                                self.nextCursor = nil
                            } else {
                                self.nextCursor = result.nextCursor
                            }
                            
                            self.isLoadingMore = false
                            isLoadingSubject.send(false)
                            feedFiltersSubject.send(self.feedFilters)
                        }
                    } catch {
                        await MainActor.run {
                            self.isLoadingMore = false
                            isLoadingSubject.send(false)
                            errorMessageSubject.send("추가 필터를 불러오는데 실패했습니다")
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        input.likeButtonTapped
            .sink { [weak self] filterId, currentIsLiked in
                guard let self = self else { return }
                
                // 낙관적 UI: 즉시 상태 변경
                if let index = self.feedFilters.firstIndex(where: { $0.id == filterId }) {
                    var updatedFilter = self.feedFilters[index]
                    let newIsLiked = !currentIsLiked
                    let newLikeCount = newIsLiked ? updatedFilter.likeCount + 1 : updatedFilter.likeCount - 1
                    
                    updatedFilter = FilterSummary(
                        id: updatedFilter.id,
                        category: updatedFilter.category,
                        title: updatedFilter.title,
                        description: updatedFilter.description,
                        mainImageURL: updatedFilter.mainImageURL,
                        creator: updatedFilter.creator,
                        photographerName: updatedFilter.photographerName,
                        likeCount: newLikeCount,
                        isLiked: newIsLiked,
                        createdAt: updatedFilter.createdAt
                    )
                    
                    self.feedFilters[index] = updatedFilter
                    feedFiltersSubject.send(self.feedFilters)
                    
                    // 서버에 반영
                    Task {
                        do {
                            _ = try await self.communityRepository.likePost(
                                postId: filterId,
                                status: newIsLiked
                            )
                        } catch {
                            // 실패 시 롤백
                            await MainActor.run {
                                if let revertIndex = self.feedFilters.firstIndex(where: { $0.id == filterId }) {
                                    var revertedFilter = self.feedFilters[revertIndex]
                                    revertedFilter = FilterSummary(
                                        id: revertedFilter.id,
                                        category: revertedFilter.category,
                                        title: revertedFilter.title,
                                        description: revertedFilter.description,
                                        mainImageURL: revertedFilter.mainImageURL,
                                        creator: revertedFilter.creator,
                                        photographerName: revertedFilter.photographerName,
                                        likeCount: currentIsLiked ? revertedFilter.likeCount + 1 : revertedFilter.likeCount - 1,
                                        isLiked: currentIsLiked,
                                        createdAt: revertedFilter.createdAt
                                    )
                                    self.feedFilters[revertIndex] = revertedFilter
                                    feedFiltersSubject.send(self.feedFilters)
                                }
                                errorMessageSubject.send("좋아요 처리에 실패했습니다")
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        return Output(
            topRankingFilters: topRankingSubject.eraseToAnyPublisher(),
            feedFilters: feedFiltersSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher()
        )
    }
}

private extension FeedViewModel {
    func fetchTopRankingFilters(
        orderBy: FilterSortType,
        categories: [FilterCategory]
    ) async throws -> [FilterSummary] {
        try await withThrowingTaskGroup(of: (FilterCategory, FilterSummary?).self) { group in
            for category in categories {
                group.addTask { [filterUsecase] in
                    let result = try await filterUsecase.fetchFilterList(
                        category: category,
                        orderBy: orderBy,
                        next: nil,
                        limit: "1"
                    )
                    return (category, result.filters.first)
                }
            }
            
            var results: [FilterCategory: FilterSummary] = [:]
            for try await (category, filter) in group {
                if let filter {
                    results[category] = filter
                }
            }
            
            return categories.compactMap { results[$0] }
        }
    }
}
