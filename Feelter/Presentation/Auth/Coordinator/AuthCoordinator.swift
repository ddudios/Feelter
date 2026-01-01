//
//  AuthCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import UIKit

/// Auth 관련 화면 flow 관리
final public class AuthCoordinator: Coordinator {

    // MARK: - Properties
    public var childCoordinators: [Coordinator] = []
    public var navigationController: UINavigationController
    public weak var finishDelegate: CoordinatorFinishDelegate?

    // MARK: - Init
    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    // MARK: - Public Methods
    public func start() {
        showLogin()
    }

    // MARK: - Internal Navigation Methods
    func showLogin() {
        let loginVC = LoginViewController()
        loginVC.coordinator = self
        navigationController.pushViewController(loginVC, animated: true)
    }

    func loginDidFinish() {
        // Auth flow 종료 → AppCoordinator에게 알림
        finishDelegate?.coordinatorDidFinish(childCoordinator: self)
    }
}

// MARK: - SocialLoginType
public enum SocialLoginType {
    case kakao
    case apple
    case google
}
