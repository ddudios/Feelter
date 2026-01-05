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
        let logoutButtonTapped: AnyPublisher<Void, Never>
        let logoutConfirmed: AnyPublisher<Void, Never>
    }

    struct Output {
        let showLogoutAlert: AnyPublisher<Void, Never>
        let logoutFinished: AnyPublisher<Void, Never>
    }

    private let logoutUsecase: LogoutUsecaseProtocol

    init(logoutUsecase: LogoutUsecaseProtocol) {
        self.logoutUsecase = logoutUsecase
    }

    func transform(input: Input) -> Output {
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
            showLogoutAlert: showLogoutAlert,
            logoutFinished: logoutFinished
        )
    }
}
