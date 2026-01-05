//
//  AuthCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import UIKit

final public class AuthCoordinator: Coordinator {

    public var childCoordinators: [Coordinator] = []
    public var navigationController: UINavigationController
    public weak var finishDelegate: CoordinatorFinishDelegate?

    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    @MainActor
    public func start() {
        showLogin()
    }

    @MainActor
    func showLogin() {
        let loginVC = LoginViewController()
        loginVC.coordinator = self
        navigationController.setViewControllers([loginVC], animated: true)
    }

    func loginDidFinish() {
        finishDelegate?.coordinatorDidFinish(childCoordinator: self)
    }
}

public enum SocialLoginType {
    case kakao
    case apple
    case google
}
