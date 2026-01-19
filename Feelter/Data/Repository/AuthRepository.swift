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

    func validateEmail(email: String) async throws -> String {
        let request = EmailValidationRequestDTO(email: email)

        let response = try await networkManager.request(
            UserRouter.validateEmail(body: request),
            type: EmailValidationResponseDTO.self
        )

        return response.message
    }

    func join(
        email: String,
        password: String,
        nick: String,
        name: String,
        introduction: String?,
        phoneNum: String?,
        hashTags: [String]?
    ) async throws -> (User, AuthToken) {
        let deviceToken = Messaging.messaging().fcmToken ?? ""

        let request = JoinRequestDTO(
            email: email,
            password: password,
            nick: nick,
            name: name,
            introduction: introduction ?? "",
            phoneNum: phoneNum ?? "",
            hashTags: hashTags ?? [],
            deviceToken: deviceToken
        )

        let response = try await networkManager.request(
            UserRouter.join(body: request),
            type: AuthResponseDTO.self
        )

        return (response.toDomain(), response.toToken())
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

    func loginWithApple(idToken: String) async throws -> (User, AuthToken) {
        let deviceToken = Messaging.messaging().fcmToken ?? ""

        let request = AppleLoginRequestDTO(
            idToken: idToken,
            deviceToken: deviceToken
        )

        let response = try await networkManager.request(
            UserRouter.appleLogin(body: request),
            type: AuthResponseDTO.self
        )

        return (response.toDomain(), response.toToken())
    }

    func loginWithKakao(oauthToken: String) async throws -> (User, AuthToken) {
        let deviceToken = Messaging.messaging().fcmToken ?? ""

        let request = KakaoLoginRequestDTO(
            oauthToken: oauthToken,
            deviceToken: deviceToken
        )

        let response = try await networkManager.request(
            UserRouter.kakaoLogin(body: request),
            type: AuthResponseDTO.self
        )

        return (response.toDomain(), response.toToken())
    }

    func logout() async throws {
        // 1. 서버에 로그아웃 요청 (실패해도 로컬 데이터는 삭제)
        do {
            try await networkManager.requestWithEmptyResponse(
                UserRouter.logout
            )
        } catch {
            // 서버 로그아웃 실패해도 무시 (토큰 만료 등으로 인한 401은 정상)
        }

        // 2. Keychain에서 토큰 및 사용자 정보 삭제 (무조건 실행)
        KeychainManager.shared.delete(account: "accessToken")
        KeychainManager.shared.delete(account: "refreshToken")
        KeychainManager.shared.delete(account: "userId")

        // 3. CoreData 초기화 (채팅 데이터 삭제)
        do {
            try CoreDataManager.shared.deleteAll(entityName: "ChatRoomEntity")
            try CoreDataManager.shared.deleteAll(entityName: "ChatMessageEntity")
        } catch {
            // CoreData 삭제 실패 무시
        }
    }
}

