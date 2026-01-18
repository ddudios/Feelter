//
//  UserRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/20/26.
//

import Foundation

final class UserRepository: UserRepositoryProtocol {
    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func fetchTodayAuthor() async throws -> TodayAuthor {
        let response = try await networkManager.request(
            UserRouter.todayAuthor,
            type: TodayAuthorResponseDTO.self
        )

        return response.toDomain()
    }

    func fetchMyProfile() async throws -> User {
        let response = try await networkManager.request(
            UserRouter.myProfile,
            type: ProfileResponseDTO.self
        )

        return response.toDomain()
    }

    func fetchProfile(userId: String) async throws -> User {
        let response = try await networkManager.request(
            UserRouter.otherProfile(userId: userId),
            type: ProfileResponseDTO.self
        )

        return response.toDomain()
    }
}
