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
        bindButton()
    }

    // MARK: - Binding
    private func bindButton() {
        loginButton.tapPublisher
            .sink { [weak self] in
                self?.coordinator?.loginDidFinish()
            }
            .store(in: &cancellables)
    }
}
