//
//  TokenRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

protocol TokenRepositoryProtocol {
    func refreshToken(accessToken: String, refreshToken: String) async throws -> AuthToken
}
