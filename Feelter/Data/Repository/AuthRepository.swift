//
//  AuthRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation
import FirebaseMessaging

final class AuthRepository: AuthRepositoryProtocol, TokenRepositoryProtocol {

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
            type: RefreshTokenResponseDTO.self
        )

        return response.toToken()
    }

    func logout() async throws {
        // 1. 서버에 로그아웃 요청 (실패해도 로컬 데이터는 삭제)
        do {
            _ = try await networkManager.request(
                UserRouter.logout,
                type: EmptyResponse.self
            )
        } catch {
            // 서버 로그아웃 실패해도 무시 (토큰 만료 등으로 인한 401은 정상)
            print("서버 로그아웃 요청 실패 (무시됨): \(error.localizedDescription)")
        }

        // 2. Keychain에서 토큰 및 사용자 정보 삭제 (무조건 실행)
        KeychainManager.shared.delete(account: "accessToken")
        KeychainManager.shared.delete(account: "refreshToken")
        KeychainManager.shared.delete(account: "userId")
    }
}

struct EmptyResponse: Decodable {}
