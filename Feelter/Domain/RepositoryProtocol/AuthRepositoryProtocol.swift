//
//  AuthRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation

protocol AuthRepositoryProtocol {
    func login(email: String, password: String) async throws -> (User, AuthToken)
}
