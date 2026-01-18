//
//  ProfileUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 2/1/26.
//

import Foundation

protocol ProfileUsecaseProtocol {
    func fetchMyProfile() async throws -> User
    func fetchProfile(userId: String) async throws -> User
}

struct ProfileUsecase: ProfileUsecaseProtocol {

    private let repository: UserRepositoryProtocol

    init(repository: UserRepositoryProtocol) {
        self.repository = repository
    }

    func fetchMyProfile() async throws -> User {
        try await repository.fetchMyProfile()
    }

    func fetchProfile(userId: String) async throws -> User {
        try await repository.fetchProfile(userId: userId)
    }
}
