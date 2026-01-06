//
//  AuthRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation

protocol AuthRepositoryProtocol {
    func refreshToken(accessToken: String, refreshToken: String) async throws -> AuthToken
    
    func login(email: String, password: String) async throws -> (User, AuthToken)
    func logout() async throws
}
