//
//  LoginViewController.swift
//  Feelter
//
//  Created by Suji Jang on 12/10/25.
//

import UIKit
import SnapKit
import Combine

final class LoginViewController: BaseViewController {

    // MARK: - Properties
    weak var coordinator: AuthCoordinator?
    private let viewModel = LoginViewModel()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Components
    private let titleLabel = {
        let label = UILabel()
        label.text = "Feelter"
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .Feelter.gray0
        return label
    }()
    private let emailTextField = FeelterTextField(placeholder: "이메일")
    private let passwordTextField = FeelterTextField(placeholder: "비밀번호", isSecure: true)
    private let loginButton = FeelterButton(title: "로그인")
    private let signUpButton = {
        let button = UIButton()
        button.setTitle("회원가입", for: .normal)
        button.setTitleColor(.Feelter.gray0, for: .normal)
        button.titleLabel?.font = TextStyle.Pretendard.caption1
        button.backgroundColor = .clear
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Configuration
    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(titleLabel)
        view.addSubview(emailTextField)
        view.addSubview(passwordTextField)
        view.addSubview(loginButton)
        view.addSubview(signUpButton)
    }

    override func configureLayout() {
        super.configureLayout()
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(80)
        }
        emailTextField.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(40)
            make.horizontalEdges.equalToSuperview().inset(40)
            make.height.equalTo(44)
        }
        passwordTextField.snp.makeConstraints { make in
            make.top.equalTo(emailTextField.snp.bottom).offset(20)
            make.horizontalEdges.equalToSuperview().inset(40)
            make.height.equalTo(44)
        }
        loginButton.snp.makeConstraints { make in
            make.top.equalTo(passwordTextField.snp.bottom).offset(20)
            make.horizontalEdges.equalToSuperview().inset(40)
            make.height.equalTo(44)
        }
        signUpButton.snp.makeConstraints { make in
            make.top.equalTo(loginButton.snp.bottom).offset(10)
            make.centerX.equalToSuperview()
        }
    }

    override func configureView() {
        super.configureView()
        bind()
    }

    // MARK: - Binding
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
            .sink { [weak self] user, token in
                // TODO: 토큰 저장
                print("로그인 성공: \(user.email)")
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
