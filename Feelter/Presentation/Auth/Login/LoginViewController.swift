//
//  LoginViewController.swift
//  Feelter
//
//  Created by Suji Jang on 12/10/25.
//

import UIKit
import SnapKit
import Combine
import AuthenticationServices

final class LoginViewController: BaseViewController {

    weak var coordinator: AuthCoordinator?
    private let viewModel: LoginViewModel
    private let authRepository: AuthRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        viewModel: LoginViewModel = DIContainer.shared.resolve(LoginViewModel.self),
        authRepository: AuthRepositoryProtocol = DIContainer.shared.resolve(AuthRepositoryProtocol.self)
    ) {
        self.viewModel = viewModel
        self.authRepository = authRepository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let titleLabel = {
        let label = UILabel()
        label.text = "Feelter"
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .Feelter.gray0
        return label
    }()
    private let emailTextField = FeelterTextField(placeholder: "이메일", textContentType: .emailAddress)
    private let passwordTextField = FeelterTextField(placeholder: "비밀번호", isSecure: true, textContentType: .password)
    private let loginButton = FeelterButton(title: "로그인")
    private let signUpButton = {
        let button = UIButton()
        button.setTitle("회원가입", for: .normal)
        button.setTitleColor(.Feelter.gray0, for: .normal)
        button.titleLabel?.font = TextStyle.Pretendard.caption1
        button.backgroundColor = .clear
        return button
    }()

    // MARK: - Social Login UI
    private let socialLoginDividerView: UIView = {
        let containerView = UIView()

        let leftLine = UIView()
        leftLine.backgroundColor = .Feelter.gray75
        containerView.addSubview(leftLine)

        let label = UILabel()
        label.text = "간편 로그인"
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .Feelter.gray75
        label.textAlignment = .center
        containerView.addSubview(label)

        let rightLine = UIView()
        rightLine.backgroundColor = .Feelter.gray75
        containerView.addSubview(rightLine)

        leftLine.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(1)
        }

        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.equalTo(leftLine.snp.trailing).offset(12)
        }

        rightLine.snp.makeConstraints { make in
            make.leading.equalTo(label.snp.trailing).offset(12)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(1)
        }

        return containerView
    }()

    private let kakaoLoginButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(red: 254/255, green: 229/255, blue: 0/255, alpha: 1.0) // 카카오 옐로우
        button.layer.cornerRadius = 25
        button.clipsToBounds = true

        let logoImageView = UIImageView(image: UIImage(systemName: "message.fill"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.tintColor = .Feelter.gray100
        button.addSubview(logoImageView)

        logoImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(24)
        }

        return button
    }()

    private let appleLoginButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .Feelter.gray0
        button.layer.cornerRadius = 25
        button.clipsToBounds = true

        let logoImageView = UIImageView(image: UIImage(systemName: "apple.logo"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.tintColor = .Feelter.gray100
        button.addSubview(logoImageView)

        logoImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(24)
        }

        return button
    }()

    private lazy var socialLoginButtonStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [appleLoginButton, kakaoLoginButton])
        stackView.axis = .horizontal
        stackView.spacing = 20
        stackView.distribution = .fillEqually
        return stackView
    }()

    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 0
        return stackView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSocialLoginButtons()
    }

    private func setupSocialLoginButtons() {
        appleLoginButton.addTarget(self, action: #selector(handleAppleLoginTap), for: .touchUpInside)
        kakaoLoginButton.addTarget(self, action: #selector(handleKakaoLoginTap), for: .touchUpInside)
    }

    @objc private func handleAppleLoginTap() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    @objc private func handleKakaoLoginTap() {
        // TODO: 카카오 로그인 구현
        showAlert(message: "카카오 로그인은 준비 중입니다.")
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(contentStackView)

        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(emailTextField)
        contentStackView.addArrangedSubview(passwordTextField)
        contentStackView.addArrangedSubview(loginButton)
        contentStackView.addArrangedSubview(signUpButton)
        contentStackView.addArrangedSubview(socialLoginDividerView)
        contentStackView.addArrangedSubview(socialLoginButtonStack)

        // 각 요소 사이의 커스텀 간격 설정
        contentStackView.setCustomSpacing(50, after: titleLabel)
        contentStackView.setCustomSpacing(20, after: emailTextField)
        contentStackView.setCustomSpacing(20, after: passwordTextField)
        contentStackView.setCustomSpacing(10, after: loginButton)
        contentStackView.setCustomSpacing(40, after: signUpButton)
        contentStackView.setCustomSpacing(20, after: socialLoginDividerView)
    }

    override func configureLayout() {
        super.configureLayout()

        // 메인 스택뷰 중앙 배치
        contentStackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.horizontalEdges.equalToSuperview().inset(40)
        }

        // 개별 요소 높이 및 너비 설정
        emailTextField.snp.makeConstraints { make in
            make.width.equalTo(contentStackView)
            make.height.equalTo(44)
        }
        passwordTextField.snp.makeConstraints { make in
            make.width.equalTo(contentStackView)
            make.height.equalTo(44)
        }
        loginButton.snp.makeConstraints { make in
            make.width.equalTo(contentStackView)
            make.height.equalTo(44)
        }
        socialLoginDividerView.snp.makeConstraints { make in
            make.width.equalTo(contentStackView)
            make.height.equalTo(20)
        }
        socialLoginButtonStack.snp.makeConstraints { make in
            make.height.equalTo(50)
        }
        appleLoginButton.snp.makeConstraints { make in
            make.width.height.equalTo(50)
        }
        kakaoLoginButton.snp.makeConstraints { make in
            make.width.height.equalTo(50)
        }
    }

    override func configureView() {
        super.configureView()
        bind()
    }

    private func bind() {
        let input = LoginViewModel.Input(
            email: emailTextField.textPublisher,
            password: passwordTextField.textPublisher,
            loginButtonTap: loginButton.tapPublisher
        )

        let output = viewModel.transform(input: input)

        output.isLoginButtonEnabled
            .assign(to: \.isEnabled, on: loginButton)
            .store(in: &cancellables)

        output.isLoading
            .sink { [weak self] isLoading in
                self?.loginButton.isEnabled = !isLoading
                // TODO: 로딩 인디케이터 표시
            }
            .store(in: &cancellables)

        output.errorMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.showAlert(message: message)
            }
            .store(in: &cancellables)

        output.loginSuccess
            .sink { [weak self] _, _ in
                self?.coordinator?.loginDidFinish()
            }
            .store(in: &cancellables)
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension LoginViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let identityToken = appleIDCredential.identityToken

            guard let identityToken = identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                showAlert(message: "Apple 로그인에 실패했습니다.")
                return
            }

            // 백엔드 API에 identityToken을 전달하여 로그인 처리
            Task {
                do {
                    let result = try await authRepository.loginWithApple(idToken: tokenString)

                    // 토큰 저장
                    KeychainManager.shared.save(token: result.1.accessToken, account: "accessToken")
                    KeychainManager.shared.save(token: result.1.refreshToken, account: "refreshToken")
                    KeychainManager.shared.save(token: result.0.id, account: "userId")

                    await MainActor.run {
                        coordinator?.loginDidFinish()
                    }
                } catch let error as NetworkError {
                    await MainActor.run {
                        showAlert(message: error.errorDescription ?? "Apple 로그인에 실패했습니다.")
                    }
                } catch {
                    await MainActor.run {
                        showAlert(message: "Apple 로그인에 실패했습니다: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        // 사용자가 취소한 경우 (에러 코드 1001)
        if nsError.code == 1001 {
            return
        }

        showAlert(message: "Apple 로그인에 실패했습니다.")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}
