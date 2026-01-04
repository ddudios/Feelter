//
//  AuthRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation
import FirebaseMessaging

final class AuthRepository: AuthRepositoryProtocol {

    func login(email: String, password: String) async throws -> (User, AuthToken) {
        let deviceToken = Messaging.messaging().fcmToken ?? ""

        // LoginRequest 생성
        let request = LoginRequestDTO(
            email: email,
            password: password,
            deviceToken: deviceToken
        )

        // TODO: API 호출 구현 필요
        // let response = try await APIService.login(request)
        // return (response.toUser(), response.toAuthToken())

        // 임시 구현 (API 구현 후 삭제)
        throw NetworkError.unknownError("API 미구현")
    }
}
