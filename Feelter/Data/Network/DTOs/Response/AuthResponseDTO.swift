//
//  AuthResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation

struct AuthResponseDTO: Decodable {
    let userId: String
    let email: String
    let nick: String
    let profileImage: String?
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case nick
        case profileImage
        case accessToken
        case refreshToken
    }
}

extension AuthResponseDTO {
    func toDomain() -> User {
        User(
            id: userId,
            email: email,
            nickname: nick,
            profileImageURL: profileImage
        )
    }

    func toToken() -> AuthToken {
        AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
