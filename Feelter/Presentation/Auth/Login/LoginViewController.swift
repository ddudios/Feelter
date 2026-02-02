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
import KakaoSDKAuth
import KakaoSDKUser

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
    private let emailErrorLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption3
        label.textColor = .Feelter.red
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let passwordTextField = FeelterTextField(placeholder: "비밀번호", isSecure: true, textContentType: .password)
    private let passwordErrorLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption3
        label.textColor = .Feelter.red
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let loginButton = FeelterButton(title: "로그인")
    private let signUpButton = {
        let button = UIButton()
        button.setTitle("회원가입", for: .normal)
        button.setTitleColor(.Feelter.gray0, for: .normal)
        button.titleLabel?.font = TextStyle.Pretendard.caption2
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
        label.font = TextStyle.Pretendard.caption2
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
        // 카카오톡 설치 여부 확인
        if UserApi.isKakaoTalkLoginAvailable() {
            // 카카오톡 앱으로 로그인
            UserApi.shared.loginWithKakaoTalk { [weak self] (oauthToken, error) in
                self?.handleKakaoLoginResult(oauthToken: oauthToken, error: error)
            }
        } else {
            // 카카오 계정으로 로그인 (웹뷰)
            UserApi.shared.loginWithKakaoAccount { [weak self] (oauthToken, error) in
                self?.handleKakaoLoginResult(oauthToken: oauthToken, error: error)
            }
        }
    }

    private func handleKakaoLoginResult(oauthToken: OAuthToken?, error: Error?) {
        if let error = error {
            showAlert(message: "카카오 로그인에 실패했습니다: \(error.localizedDescription)")
            return
        }

        guard let oauthToken = oauthToken else {
            showAlert(message: "카카오 로그인에 실패했습니다.")
            return
        }

        // 카카오 사용자 정보 가져오기
        UserApi.shared.me { [weak self] (user, error) in
            if let error = error {
                Task { @MainActor in
                    self?.showAlert(message: "카카오 사용자 정보를 가져올 수 없습니다: \(error.localizedDescription)")
                }
                return
            }

            guard let user = user else {
                Task { @MainActor in
                    self?.showAlert(message: "카카오 사용자 정보를 가져올 수 없습니다.")
                }
                return
            }

            // 이메일이 없는 경우 추가 동의 요청
            if user.kakaoAccount?.email == nil {
                // 추가 동의 필요 여부 확인
                if let emailNeedsAgreement = user.kakaoAccount?.emailNeedsAgreement, emailNeedsAgreement {
                    // 이메일 scope를 포함하여 재로그인 (웹뷰 사용)
                    UserApi.shared.loginWithKakaoAccount(scopes: ["account_email"]) { [weak self] (newOauthToken, error) in
                        if let error = error {
                            Task { @MainActor in
                                self?.showAlert(message: "이메일 제공 동의가 필요합니다. 로그인을 다시 시도해주세요.")
                            }
                            return
                        }

                        guard let newOauthToken = newOauthToken else {
                            Task { @MainActor in
                                self?.showAlert(message: "이메일 제공 동의가 필요합니다.")
                            }
                            return
                        }

                        // 사용자 정보 재조회
                        UserApi.shared.me { [weak self] (updatedUser, error) in
                            if let error = error {
                                return
                            }

                            if let email = updatedUser?.kakaoAccount?.email {
                                self?.proceedWithKakaoLogin(oauthToken: newOauthToken.accessToken)
                            } else {
                                Task { @MainActor in
                                    self?.showAlert(message: "카카오 계정에 이메일이 등록되어 있지 않습니다. 카카오톡 앱에서 이메일을 등록해주세요.")
                                }
                            }
                        }
                    }
                } else {
                    Task { @MainActor in
                        self?.showAlert(message: "카카오 계정에 이메일이 등록되어 있지 않습니다. 카카오톡 앱에서 이메일을 등록해주세요.")
                    }
                }
                return
            }

            // 서버에 OAuth 토큰 전달하여 로그인 처리
            self?.proceedWithKakaoLogin(oauthToken: oauthToken.accessToken)
        }
    }

    private func proceedWithKakaoLogin(oauthToken: String) {
        Task {
            do {
                let result = try await authRepository.loginWithKakao(oauthToken: oauthToken)

                // 토큰 저장
                KeychainManager.shared.save(token: result.1.accessToken, account: "accessToken")
                KeychainManager.shared.save(token: result.1.refreshToken, account: "refreshToken")
                KeychainManager.shared.save(token: result.0.id, account: "userId")

                await MainActor.run {
                    coordinator?.loginDidFinish()
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    showAlert(message: error.errorDescription ?? "카카오 로그인에 실패했습니다.")
                }
            } catch {
                await MainActor.run {
                    showAlert(message: "카카오 로그인에 실패했습니다: \(error.localizedDescription)")
                }
            }
        }
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(contentStackView)

        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(emailTextField)
        contentStackView.addArrangedSubview(emailErrorLabel)
        contentStackView.addArrangedSubview(passwordTextField)
        contentStackView.addArrangedSubview(passwordErrorLabel)
        contentStackView.addArrangedSubview(loginButton)
        contentStackView.addArrangedSubview(signUpButton)
        contentStackView.addArrangedSubview(socialLoginDividerView)
        contentStackView.addArrangedSubview(socialLoginButtonStack)

        // 각 요소 사이의 커스텀 간격 설정
        contentStackView.setCustomSpacing(50, after: titleLabel)
        contentStackView.setCustomSpacing(20, after: emailTextField) // 초기값: 에러 없을 때 간격
        contentStackView.setCustomSpacing(20, after: emailErrorLabel)
        contentStackView.setCustomSpacing(20, after: passwordTextField) // 초기값: 에러 없을 때 간격
        contentStackView.setCustomSpacing(20, after: passwordErrorLabel)
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
        emailErrorLabel.snp.makeConstraints { make in
            make.width.equalTo(contentStackView)
        }
        passwordTextField.snp.makeConstraints { make in
            make.width.equalTo(contentStackView)
            make.height.equalTo(44)
        }
        passwordErrorLabel.snp.makeConstraints { make in
            make.width.equalTo(contentStackView)
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
        signUpButton.addTarget(self, action: #selector(signUpButtonTapped), for: .touchUpInside)
    }

    @objc private func signUpButtonTapped() {
        coordinator?.showJoin()
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

        // 이메일 유효성 검증 바인딩
        output.emailValidationError
            .sink { [weak self] errorMessage in
                guard let self = self else { return }

                if let errorMessage = errorMessage {
                    self.emailTextField.setBorderState(.error)
                    self.emailErrorLabel.text = errorMessage
                    self.emailErrorLabel.isHidden = false
                    // 에러가 있을 때: 4pt 간격
                    self.contentStackView.setCustomSpacing(4, after: self.emailTextField)
                } else {
                    self.emailTextField.setBorderState(.normal)
                    self.emailErrorLabel.isHidden = true
                    // 에러가 없을 때: 20pt 간격으로 복구
                    self.contentStackView.setCustomSpacing(20, after: self.emailTextField)
                }
            }
            .store(in: &cancellables)

        // 비밀번호 유효성 검증 바인딩
        output.passwordValidationError
            .sink { [weak self] errorMessage in
                guard let self = self else { return }

                if let errorMessage = errorMessage {
                    self.passwordTextField.setBorderState(.error)
                    self.passwordErrorLabel.text = errorMessage
                    self.passwordErrorLabel.isHidden = false
                    // 에러가 있을 때: 4pt 간격
                    self.contentStackView.setCustomSpacing(4, after: self.passwordTextField)
                } else {
                    self.passwordTextField.setBorderState(.normal)
                    self.passwordErrorLabel.isHidden = true
                    // 에러가 없을 때: 20pt 간격으로 복구
                    self.contentStackView.setCustomSpacing(20, after: self.passwordTextField)
                }
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
