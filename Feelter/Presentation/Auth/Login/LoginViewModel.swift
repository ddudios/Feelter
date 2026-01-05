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

        // 버튼 활성화 상태 (이메일, 비밀번호 둘 다 비어있지 않을 때)
        let isLoginButtonEnabled = Publishers.CombineLatest(input.email, input.password)
            .map { email, password in
                let emailText = email ?? ""
                let passwordText = password ?? ""
                return !emailText.isEmpty && !passwordText.isEmpty
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
                        print("에러 타입: \(type(of: error))")
                        print(error.localizedDescription)

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
            loginSuccess: loginSuccessSubject.eraseToAnyPublisher()
        )
    }
}
