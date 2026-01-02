//
//  AuthToken.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation

struct AuthToken {
    let accessToken: String
    let refreshToken: String

    init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}
