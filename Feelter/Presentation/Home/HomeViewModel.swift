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
        let bannerTapped: AnyPublisher<Banner, Never>
        let filterTapped: AnyPublisher<FilterSummary, Never>
    }

    struct Output {
        let todayFilter: AnyPublisher<TodayFilter, Never>
        let banners: AnyPublisher<[Banner], Never>
        let hotTrends: AnyPublisher<[FilterSummary], Never>
        let todayAuthor: AnyPublisher<TodayAuthor, Never>
        let isLoading: AnyPublisher<Bool, Never>
        let errorMessage: AnyPublisher<String?, Never>
        let presentWebView: AnyPublisher<String, Never>
        let presentFilterDetail: AnyPublisher<String, Never>
    }

    private let filterUsecase: FilterUsecaseProtocol
    private let bannerUsecase: BannerUsecaseProtocol
    private let tokenRepository: TokenRepositoryProtocol
    private let todayAuthorUsecase: TodayAuthorUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        filterUsecase: FilterUsecaseProtocol,
        bannerUsecase: BannerUsecaseProtocol,
        tokenRepository: TokenRepositoryProtocol,
        todayAuthorUsecase: TodayAuthorUsecaseProtocol
    ) {
        self.filterUsecase = filterUsecase
        self.bannerUsecase = bannerUsecase
        self.tokenRepository = tokenRepository
        self.todayAuthorUsecase = todayAuthorUsecase
    }

    func transform(input: Input) -> Output {
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let todayFilterSubject = PassthroughSubject<TodayFilter, Never>()
        let bannersSubject = PassthroughSubject<[Banner], Never>()
        let hotTrendsSubject = PassthroughSubject<[FilterSummary], Never>()
        let todayAuthorSubject = PassthroughSubject<TodayAuthor, Never>()
        let errorMessageSubject = PassthroughSubject<String?, Never>()
        let presentWebViewSubject = PassthroughSubject<String, Never>()
        let presentFilterDetailSubject = PassthroughSubject<String, Never>()

        input.viewDidLoad
            .sink { [weak self] in
                guard let self = self else { return }

                isLoadingSubject.send(true)

                Task {
                    do {
                        // 오늘의 필터, 배너, 핫 트렌드, 오늘의 작가를 동시에 가져오기
                        async let filter = self.filterUsecase.fetchTodayFilter()
                        async let banners = self.bannerUsecase.fetchBanners()
                        async let hotTrends = self.filterUsecase.fetchHotTrends()
                        async let todayAuthor = self.todayAuthorUsecase.fetchTodayAuthor()

                        let (filterResult, bannersResult, hotTrendsResult, todayAuthorResult) = try await (
                            filter,
                            banners,
                            hotTrends,
                            todayAuthor
                        )

                        await MainActor.run {
                            isLoadingSubject.send(false)
                            todayFilterSubject.send(filterResult)
                            bannersSubject.send(bannersResult)
                            hotTrendsSubject.send(hotTrendsResult)
                            todayAuthorSubject.send(todayAuthorResult)
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

        // 배너 탭 처리: 토큰 갱신 후 WebView 표시
        input.bannerTapped
            .sink { [weak self] banner in
                guard let self = self else { return }
                guard banner.linkType == .webView else {
                    return
                }

                isLoadingSubject.send(true)

                Task {
                    do {
                        // 토큰 갱신
                        guard let accessToken = KeychainManager.shared.read(account: "accessToken"),
                              let refreshToken = KeychainManager.shared.read(account: "refreshToken") else {
                            // 토큰이 없으면 로그아웃
                            await MainActor.run {
                                isLoadingSubject.send(false)
                                NotificationCenter.default.post(name: .unauthorizedError, object: nil)
                            }
                            return
                        }

                        let newToken = try await self.tokenRepository.refreshToken(
                            accessToken: accessToken,
                            refreshToken: refreshToken
                        )

                        // 새 토큰 저장
                        KeychainManager.shared.save(token: newToken.accessToken, account: "accessToken")
                        KeychainManager.shared.save(token: newToken.refreshToken, account: "refreshToken")

                        // WebView 표시
                        await MainActor.run {
                            isLoadingSubject.send(false)
                            let fullURL = "\(Config.baseURL)\(banner.linkPath)"
                            presentWebViewSubject.send(fullURL)
                        }
                    } catch {
                        // 토큰 갱신 실패 -> 로그아웃
                        await MainActor.run {
                            isLoadingSubject.send(false)
                            KeychainManager.shared.delete(account: "accessToken")
                            KeychainManager.shared.delete(account: "refreshToken")
                            NotificationCenter.default.post(name: .unauthorizedError, object: nil)
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // 핫 트렌드 탭 처리: 필터 상세 화면으로 이동
        input.filterTapped
            .sink { filter in
                presentFilterDetailSubject.send(filter.id)
            }
            .store(in: &cancellables)

        return Output(
            todayFilter: todayFilterSubject.eraseToAnyPublisher(),
            banners: bannersSubject.eraseToAnyPublisher(),
            hotTrends: hotTrendsSubject.eraseToAnyPublisher(),
            todayAuthor: todayAuthorSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher(),
            presentWebView: presentWebViewSubject.eraseToAnyPublisher(),
            presentFilterDetail: presentFilterDetailSubject.eraseToAnyPublisher()
        )
    }
}
