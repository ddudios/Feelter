//
//  AuthRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation
import FirebaseMessaging

final class AuthRepository: AuthRepositoryProtocol {

    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol = NetworkManager()) {
        self.networkManager = networkManager
    }

    func login(email: String, password: String) async throws -> (User, AuthToken) {
        let deviceToken = Messaging.messaging().fcmToken ?? ""

        let request = LoginRequestDTO(
            email: email,
            password: password,
            deviceToken: deviceToken
        )

        let response = try await networkManager.request(
            UserRouter.login(body: request),
            type: AuthResponseDTO.self
        )

        return (response.toDomain(), response.toToken())
    }

    func refreshToken(accessToken: String, refreshToken: String) async throws -> AuthToken {
        let response = try await networkManager.request(
            AuthRouter.refresh(accessToken: accessToken, refreshToken: refreshToken),
            type: AuthResponseDTO.self
        )

        return response.toToken()
    }
}
