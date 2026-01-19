//
//  AuthRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation

protocol AuthRepositoryProtocol {
    func validateEmail(email: String) async throws -> String
    func join(email: String, password: String, nick: String, name: String, introduction: String?, phoneNum: String?, hashTags: [String]?) async throws -> (User, AuthToken)
    func login(email: String, password: String) async throws -> (User, AuthToken)
    func loginWithApple(idToken: String) async throws -> (User, AuthToken)
    func loginWithKakao(oauthToken: String) async throws -> (User, AuthToken)
    func logout() async throws
}
