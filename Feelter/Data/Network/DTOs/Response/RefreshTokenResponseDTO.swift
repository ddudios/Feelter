//
//  RefreshTokenResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct RefreshTokenResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
}

extension RefreshTokenResponseDTO {
    func toToken() -> AuthToken {
        AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
