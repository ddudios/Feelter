//
//  AuthCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import UIKit

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
        finishDelegate?.coordinatorDidFinish(childCoordinator: self)
    }
}

// MARK: - SocialLoginType
public enum SocialLoginType {
    case kakao
    case apple
    case google
}
