//
//  FilterDetailViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation
import Combine

final class FilterDetailViewModel: ViewModelProtocol {
    struct Input {
        let viewDidLoad: AnyPublisher<String, Never>
        let likeButtonTapped: AnyPublisher<Void, Never>
    }
    
    struct Output {
        let filterDetail: AnyPublisher<FilterDetail, Never>
        let isLiked: AnyPublisher<Bool, Never>
        let likeCount: AnyPublisher<Int, Never>
        let errorMessage: AnyPublisher<String?, Never>
    }
    
    private let filterUsecase: FilterUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentFilterId: String?
    private var currentIsLiked = false
    private var currentLikeCount: Int?
    
    init(filterUsecase: FilterUsecaseProtocol) {
        self.filterUsecase = filterUsecase
    }
    
    func transform(input: Input) -> Output {
        let filterDetailSubject = CurrentValueSubject<FilterDetail?, Never>(nil)
        let isLikedSubject = CurrentValueSubject<Bool, Never>(false)
        let likeCountSubject = CurrentValueSubject<Int?, Never>(nil)
        let errorMessageSubject = PassthroughSubject<String?, Never>()
        
        input.viewDidLoad
            .sink { [weak self] filterId in
                guard let self else { return }
                self.currentFilterId = filterId
                Task {
                    do {
                        let detail = try await self.filterUsecase.fetchFilter(id: filterId)
                        await MainActor.run {
                            self.currentIsLiked = detail.isLiked
                            self.currentLikeCount = detail.likeCount
                            filterDetailSubject.send(detail)
                            isLikedSubject.send(detail.isLiked)
                            likeCountSubject.send(detail.likeCount)
                        }
                    } catch {
                        await MainActor.run {
                            errorMessageSubject.send("필터 상세를 불러오는데 실패했습니다: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        input.likeButtonTapped
            .sink { [weak self] in
                guard let self, let filterId = self.currentFilterId else { return }
                let previousIsLiked = self.currentIsLiked
                let previousLikeCount = self.currentLikeCount
                let newIsLiked = !previousIsLiked
                self.currentIsLiked = newIsLiked
                isLikedSubject.send(newIsLiked)
                if let previousLikeCount {
                    let newLikeCount = max(previousLikeCount + (newIsLiked ? 1 : -1), 0)
                    self.currentLikeCount = newLikeCount
                    likeCountSubject.send(newLikeCount)
                }
                
                Task {
                    do {
                        let updatedStatus = try await self.filterUsecase.likeFilter(id: filterId, status: newIsLiked)
                        await MainActor.run {
                            self.currentIsLiked = updatedStatus
                            if updatedStatus != newIsLiked {
                                isLikedSubject.send(updatedStatus)
                                if let previousLikeCount {
                                    self.currentLikeCount = previousLikeCount
                                    likeCountSubject.send(previousLikeCount)
                                }
                            }
                        }
                    } catch {
                        await MainActor.run {
                            self.currentIsLiked = previousIsLiked
                            isLikedSubject.send(previousIsLiked)
                            if let previousLikeCount {
                                self.currentLikeCount = previousLikeCount
                                likeCountSubject.send(previousLikeCount)
                            }
                            errorMessageSubject.send("좋아요 처리에 실패했습니다")
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        return Output(
            filterDetail: filterDetailSubject.compactMap { $0 }.eraseToAnyPublisher(),
            isLiked: isLikedSubject.eraseToAnyPublisher(),
            likeCount: likeCountSubject.compactMap { $0 }.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher()
        )
    }
}
