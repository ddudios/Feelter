//
//  TodayAuthorUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/20/26.
//

import Foundation

protocol TodayAuthorUsecaseProtocol {
    func fetchTodayAuthor() async throws -> TodayAuthor
}

struct TodayAuthorUsecase: TodayAuthorUsecaseProtocol {
    private let repository: UserRepositoryProtocol

    init(repository: UserRepositoryProtocol) {
        self.repository = repository
    }

    func fetchTodayAuthor() async throws -> TodayAuthor {
        try await repository.fetchTodayAuthor()
    }
}
