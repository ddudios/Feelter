//
//  LoginViewController.swift
//  Feelter
//
//  Created by Suji Jang on 12/10/25.
//

import UIKit
import SnapKit

final class LoginViewController: BaseViewController {

    // MARK: - Properties
    weak var coordinator: AuthCoordinator?

    // MARK: - UI Components
    private let titleLabel = {
        let label = UILabel()
        label.text = "Feelter"
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .Feelter.gray0
        return label
    }()
    private lazy var loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("로그인 하기", for: .normal)
        button.titleLabel?.font = TextStyle.Pretendard.body1
        button.backgroundColor = .Feelter.gray75
        button.setTitleColor(.Feelter.blackTurquoise, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
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
        view.addSubview(loginButton)
    }

    override func configureLayout() {
        super.configureLayout()
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(50)
        }
        loginButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    override func configureView() {
        super.configureView()
    }

    // MARK: - Actions
    @objc private func loginButtonTapped() {
        // Coordinator를 통해 로그인 완료 알림
        coordinator?.loginDidFinish()
    }
}
