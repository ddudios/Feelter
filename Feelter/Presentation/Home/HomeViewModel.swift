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
    private let userRepository: UserRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        filterUsecase: FilterUsecaseProtocol,
        bannerUsecase: BannerUsecaseProtocol,
        tokenRepository: TokenRepositoryProtocol,
        todayAuthorUsecase: TodayAuthorUsecaseProtocol,
        userRepository: UserRepositoryProtocol
    ) {
        self.filterUsecase = filterUsecase
        self.bannerUsecase = bannerUsecase
        self.tokenRepository = tokenRepository
        self.todayAuthorUsecase = todayAuthorUsecase
        self.userRepository = userRepository
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
                        // ========================================
                        // 🔴 목데이터 모드 (개발/테스트용)
                        // ========================================
                        // 사용 시: 아래 주석 해제 + 원본 API 모드 주석 처리

                        async let filterDetailResult = self.filterUsecase.fetchFilter(id: "69853b342d826cebc45840c5")
                        async let bannersResult = self.bannerUsecase.fetchBanners()
                        async let hotTrendsResult = self.filterUsecase.fetchHotTrends()
                        async let userProfileResult = self.userRepository.fetchProfile(userId: "6957530cf1736c2b36c4e02e")
                        async let userFiltersResult = self.filterUsecase.fetchUserFilters(userId: "6957530cf1736c2b36c4e02e", next: nil, limit: nil)

                        let (filterDetail, banners, hotTrends, userProfile, userFilters) = try await (
                            filterDetailResult,
                            bannersResult,
                            hotTrendsResult,
                            userProfileResult,
                            userFiltersResult
                        )

                        // FilterDetail을 TodayFilter로 변환
                        let todayFilter = TodayFilter(
                            id: filterDetail.id,
                            title: filterDetail.title,
                            introduction: "공기를 담은 필터",
                            description: filterDetail.description,
                            mainImageURL: filterDetail.previewImages.first ?? "",
                            createdAt: filterDetail.createdAt
                        )

                        // User를 TodayAuthor로 변환 (커스텀 introduction, description 사용)
                        let authorInfo = AuthorInfo(
                            id: userProfile.id,
                            nickname: userProfile.nickname,
                            name: userProfile.name ?? "",
                            introduction: "빛과 공기의 온도를 사진에 담아내는 작가",
                            description: "과하지 않은 보정과 절제된 색감을 통해\n사진이 가진 본연의 분위기를 섬세하게 살려내는 사진작가입니다.\n일상의 순간이 조금 더 부드럽게 기억되길 바라는 사람들,\n자연스러운 톤과 감정의 흐름을 중요하게 여기는 이들에게\n김하린의 필터는 조용한 선택지가 되어줍니다.",
                            profileImageURL: userProfile.profileImageURL,
                            hashTags: userProfile.hashTags
                        )
                        let todayAuthor = TodayAuthor(author: authorInfo, filters: userFilters.filters)

                        // ========================================
                        // ✅ 원본 API 모드 (프로덕션용)
                        // ========================================
                        // 사용 시: 아래 주석 해제 + 목데이터 모드 주석 처리

//                        async let todayFilterResult = self.filterUsecase.fetchTodayFilter()
//                        async let bannersResult = self.bannerUsecase.fetchBanners()
//                        async let hotTrendsResult = self.filterUsecase.fetchHotTrends()
//                        async let todayAuthorResult = self.todayAuthorUsecase.fetchTodayAuthor()
//
//                        let (todayFilter, banners, hotTrends, todayAuthor) = try await (
//                            todayFilterResult,
//                            bannersResult,
//                            hotTrendsResult,
//                            todayAuthorResult
//                        )
                        
                        // 공통
                        await MainActor.run {
                            isLoadingSubject.send(false)
                            todayFilterSubject.send(todayFilter)
                            bannersSubject.send(banners)
                            hotTrendsSubject.send(hotTrends)
                            todayAuthorSubject.send(todayAuthor)
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
