//
//  LogoutUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation

protocol LogoutUsecaseProtocol {
    func execute() async throws
}

struct LogoutUsecase: LogoutUsecaseProtocol {

    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws {
        try await repository.logout()
    }
}
