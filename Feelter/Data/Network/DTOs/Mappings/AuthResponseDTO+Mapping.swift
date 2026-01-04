//
//  AuthResponseDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation

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
