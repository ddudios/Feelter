//
//  LoginResponse+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation

extension LoginResponse {
    func toUser() -> User {
        User(
            id: userId,
            email: email,
            nickname: nick,
            profileImageURL: profileImage
        )
    }

    func toAuthToken() -> AuthToken {
        AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
