//
//  LoginViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import Foundation
import Combine

final class LoginViewModel: ViewModelProtocol {
    struct Input {
        let email: AnyPublisher<String?, Never>
        let password: AnyPublisher<String?, Never>
        let loginButtonTap: AnyPublisher<Void, Never>
    }

    struct Output {
        let isLoginButtonEnabled: AnyPublisher<Bool, Never>
        let isLoading: AnyPublisher<Bool, Never>
        let errorMessage: AnyPublisher<String?, Never>
        let loginSuccess: AnyPublisher<(User, AuthToken), Never>
        let emailValidationError: AnyPublisher<String?, Never>
        let passwordValidationError: AnyPublisher<String?, Never>
    }

    private let usecase: LoginUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()

    init(usecase: LoginUsecaseProtocol) {
        self.usecase = usecase
    }

    func transform(input: Input) -> Output {
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let errorMessageSubject = PassthroughSubject<String?, Never>()
        let loginSuccessSubject = PassthroughSubject<(User, AuthToken), Never>()

        // 이메일, 비밀번호 상태 저장
        let emailState = CurrentValueSubject<String?, Never>(nil)
        let passwordState = CurrentValueSubject<String?, Never>(nil)

        input.email
            .assign(to: \.value, on: emailState)
            .store(in: &cancellables)

        input.password
            .assign(to: \.value, on: passwordState)
            .store(in: &cancellables)

        // 이메일 실시간 유효성 검증
        let emailValidationError = input.email
            .map { email -> String? in
                guard let email = email, !email.isEmpty else {
                    return nil // 빈 값일 때는 에러 표시 안 함
                }

                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
                let isValid = emailPredicate.evaluate(with: email)

                return isValid ? nil : "올바른 이메일 형식을 입력해주세요"
            }
            .eraseToAnyPublisher()

        // 비밀번호 실시간 유효성 검증
        let passwordValidationError = input.password
            .map { password -> String? in
                guard let password = password, !password.isEmpty else {
                    return nil // 빈 값일 때는 에러 표시 안 함
                }

                return password.count >= 8 ? nil : "비밀번호는 8자 이상이어야 합니다"
            }
            .eraseToAnyPublisher()

        // 버튼 활성화 상태 (이메일, 비밀번호 둘 다 유효할 때)
        let isLoginButtonEnabled = Publishers.CombineLatest3(
            input.email,
            input.password,
            Publishers.CombineLatest(emailValidationError, passwordValidationError)
        )
        .map { email, password, validationErrors in
            let emailText = email ?? ""
            let passwordText = password ?? ""
            let (emailError, passwordError) = validationErrors

            return !emailText.isEmpty && !passwordText.isEmpty && emailError == nil && passwordError == nil
        }
        .eraseToAnyPublisher()

        input.loginButtonTap
            .sink { [weak self] in
                guard let self = self else { return }

                let emailText = emailState.value ?? ""
                let passwordText = passwordState.value ?? ""

                isLoadingSubject.send(true)

                Task {
                    do {
                        let result = try await self.usecase.execute(
                            email: emailText,
                            password: passwordText
                        )

                        KeychainManager.shared.save(token: result.1.accessToken, account: "accessToken")
                        KeychainManager.shared.save(token: result.1.refreshToken, account: "refreshToken")
                        KeychainManager.shared.save(token: result.0.id, account: "userId")

                        await MainActor.run {
                            isLoadingSubject.send(false)
                            loginSuccessSubject.send(result)
                        }
                    } catch let error as ValidationError {
                        await MainActor.run {
                            isLoadingSubject.send(false)
                            errorMessageSubject.send(error.description)
                        }
                    } catch let error as NetworkError {
                        await MainActor.run {
                            isLoadingSubject.send(false)
                            errorMessageSubject.send(error.errorDescription)
                        }
                    } catch {

                        await MainActor.run {
                            isLoadingSubject.send(false)
                            errorMessageSubject.send("알 수 없는 오류가 발생했습니다: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .store(in: &cancellables)

        return Output(
            isLoginButtonEnabled: isLoginButtonEnabled,
            isLoading: isLoadingSubject.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher(),
            loginSuccess: loginSuccessSubject.eraseToAnyPublisher(),
            emailValidationError: emailValidationError,
            passwordValidationError: passwordValidationError
        )
    }
}
