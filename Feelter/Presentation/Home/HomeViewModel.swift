//
//  HomeViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation
import Combine

final class HomeViewModel: ViewModelProtocol {

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
    }

    struct Output {
        let todayFilter: AnyPublisher<Filter, Never>
        let banners: AnyPublisher<[Banner], Never>
        let isLoading: AnyPublisher<Bool, Never>
        let errorMessage: AnyPublisher<String?, Never>
    }

    private let filterUsecase: FilterUsecaseProtocol
    private let bannerUsecase: BannerUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()

    init(filterUsecase: FilterUsecaseProtocol, bannerUsecase: BannerUsecaseProtocol) {
        self.filterUsecase = filterUsecase
        self.bannerUsecase = bannerUsecase
    }

    func transform(input: Input) -> Output {
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let todayFilterSubject = PassthroughSubject<Filter, Never>()
        let bannersSubject = PassthroughSubject<[Banner], Never>()
        let errorMessageSubject = PassthroughSubject<String?, Never>()

        input.viewDidLoad
            .sink { [weak self] in
                guard let self = self else { return }

                isLoadingSubject.send(true)

                Task {
                    do {
                        // 오늘의 필터와 배너를 동시에 가져오기
                        async let filter = self.filterUsecase.fetchTodayFilter()
                        async let banners = self.bannerUsecase.fetchBanners()

                        let (filterResult, bannersResult) = try await (filter, banners)

                        await MainActor.run {
                            isLoadingSubject.send(false)
                            todayFilterSubject.send(filterResult)
                            bannersSubject.send(bannersResult)
                        }
                    } catch {
                        await MainActor.run {
                            isLoadingSubject.send(false)
                            errorMessageSubject.send("데이터를 불러오는데 실패했습니다: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .store(in: &cancellables)

        return Output(
            todayFilter: todayFilterSubject.eraseToAnyPublisher(),
            banners: bannersSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher()
        )
    }
}
