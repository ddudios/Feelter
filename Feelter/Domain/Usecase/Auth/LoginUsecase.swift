//
//  LoginUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation

protocol LoginUsecaseProtocol {
    func execute(email: String, password: String, deviceToken: String) async throws -> (User, AuthToken)
}

final class LoginUsecase: LoginUsecaseProtocol {
    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    func execute(email: String, password: String, deviceToken: String) async throws -> (User, AuthToken) {
        // 이메일 유효성 검사
        guard !email.isEmpty else {
            throw ValidationError.emptyEmail
        }

        guard isValidEmail(email) else {
            throw ValidationError.invalidEmail
        }

        // 비밀번호 유효성 검사
        guard !password.isEmpty else {
            throw ValidationError.emptyPassword
        }

        guard isValidPassword(password) else {
            throw ValidationError.invalidPassword
        }

        // Repository를 통해 로그인
        return try await repository.login(email: email, password: password, deviceToken: deviceToken)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 8
    }
}
