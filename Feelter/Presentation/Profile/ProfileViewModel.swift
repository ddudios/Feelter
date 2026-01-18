//
//  ProfileViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation
import Combine

final class ProfileViewModel: ViewModelProtocol {

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let logoutButtonTapped: AnyPublisher<Void, Never>
        let logoutConfirmed: AnyPublisher<Void, Never>
    }

    struct Output {
        let profile: AnyPublisher<User, Never>
        let filters: AnyPublisher<[FilterSummary], Never>
        let errorMessage: AnyPublisher<String?, Never>
        let showLogoutAlert: AnyPublisher<Void, Never>
        let logoutFinished: AnyPublisher<Void, Never>
    }

    private let logoutUsecase: LogoutUsecaseProtocol
    private let profileUsecase: ProfileUsecaseProtocol
    private let filterUsecase: FilterUsecaseProtocol
    private let userId: String?
    private var cancellables = Set<AnyCancellable>()

    var isMyProfile: Bool {
        userId == nil
    }

    init(
        logoutUsecase: LogoutUsecaseProtocol,
        profileUsecase: ProfileUsecaseProtocol,
        filterUsecase: FilterUsecaseProtocol,
        userId: String? = nil
    ) {
        self.logoutUsecase = logoutUsecase
        self.profileUsecase = profileUsecase
        self.filterUsecase = filterUsecase
        self.userId = userId
    }

    func transform(input: Input) -> Output {
        let profileSubject = PassthroughSubject<User, Never>()
        let filtersSubject = PassthroughSubject<[FilterSummary], Never>()
        let errorMessageSubject = PassthroughSubject<String?, Never>()

        input.viewDidLoad
            .sink { [weak self] in
                self?.loadProfile(
                    profileSubject: profileSubject,
                    filtersSubject: filtersSubject,
                    errorMessageSubject: errorMessageSubject
                )
            }
            .store(in: &cancellables)

        let showLogoutAlert = input.logoutButtonTapped
            .eraseToAnyPublisher()

        let logoutFinished = input.logoutConfirmed
            .flatMap { [weak self] _ -> AnyPublisher<Void, Never> in
                guard let self = self else { return Empty().eraseToAnyPublisher() }

                return Future { promise in
                    Task {
                        // 비즈니스 로직: API 호출, 토큰 삭제
                        try? await self.logoutUsecase.execute()

                        // 성공하든 실패하든 화면 전환 신호 전달
                        promise(.success(()))
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()

        return Output(
            profile: profileSubject.eraseToAnyPublisher(),
            filters: filtersSubject.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher(),
            showLogoutAlert: showLogoutAlert,
            logoutFinished: logoutFinished
        )
    }

    private func loadProfile(
        profileSubject: PassthroughSubject<User, Never>,
        filtersSubject: PassthroughSubject<[FilterSummary], Never>,
        errorMessageSubject: PassthroughSubject<String?, Never>
    ) {
        Task {
            do {
                guard let targetUserId = resolvedUserId() else {
                    await MainActor.run {
                        errorMessageSubject.send("사용자 정보를 찾을 수 없습니다.")
                    }
                    return
                }

                async let profileResult: User = {
                    if isMyProfile {
                        return try await profileUsecase.fetchMyProfile()
                    }
                    return try await profileUsecase.fetchProfile(userId: targetUserId)
                }()

                async let filtersResult: [FilterSummary] = fetchAllUserFilters(userId: targetUserId)
                let (profile, filters) = try await (profileResult, filtersResult)

                await MainActor.run {
                    profileSubject.send(profile)
                    filtersSubject.send(filters)
                }
            } catch {
                await MainActor.run {
                    errorMessageSubject.send("프로필 정보를 불러오는데 실패했습니다: \(error.localizedDescription)")
                }
            }
        }
    }

    private func resolvedUserId() -> String? {
        if let userId, !userId.isEmpty {
            return userId
        }
        let currentUserId = KeychainManager.shared.read(account: "userId")
        return currentUserId?.isEmpty == true ? nil : currentUserId
    }

    private func fetchAllUserFilters(userId: String) async throws -> [FilterSummary] {
        var filters: [FilterSummary] = []
        var nextCursor: String?

        repeat {
            let result = try await filterUsecase.fetchUserFilters(
                userId: userId,
                next: nextCursor,
                limit: "50"
            )
            filters.append(contentsOf: result.filters)
            nextCursor = result.nextCursor
        } while nextCursor != nil

        return filters
    }
}
