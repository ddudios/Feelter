//
//  AppCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import UIKit

// 앱 전체 flow를 관리하는 최상위 Coordinator
final public class AppCoordinator: Coordinator {

    public var childCoordinators: [Coordinator] = []
    public var navigationController: UINavigationController
    private var isLoggingOut = false  // 로그아웃 진행 중 플래그

    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @MainActor
    public func start() {
        let isLoggedIn = checkLoginStatus()

        if isLoggedIn {
            showMainFlow()
        } else {
            showAuthFlow()
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnauthorizedError),
            name: .unauthorizedError,
            object: nil
        )
    }

    private func checkLoginStatus() -> Bool {
        let accessToken = KeychainManager.shared.read(account: "accessToken")
        return accessToken != nil
    }
    
    @MainActor
    private func showAuthFlow() {
        let authCoordinator = AuthCoordinator(navigationController: navigationController)
        authCoordinator.finishDelegate = self
        addChildCoordinator(authCoordinator)
        authCoordinator.start()
    }

    @MainActor
    private func showMainFlow() {
        let tabBarCoordinator = TabBarCoordinator(navigationController: navigationController)
        addChildCoordinator(tabBarCoordinator)
        tabBarCoordinator.start()
    }

    @objc private func handleUnauthorizedError() {
        guard !isLoggingOut else { return }
        isLoggingOut = true

        Task { @MainActor in
            showLoginExpiredAlert()
        }
    }

    @MainActor
    private func showLoginExpiredAlert() {
        let alert = UIAlertController(
            title: "로그인 만료",
            message: "로그인이 만료되었습니다.\n다시 로그인해주세요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.performLogout()
        })

        // 최상위 ViewController에서 알림 표시
        if let topViewController = getTopViewController() {
            topViewController.present(alert, animated: true)
        } else {
            performLogout()
        }
    }

    private func getTopViewController() -> UIViewController? {
        var topViewController = navigationController.viewControllers.first

        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }

        if let tabBarController = topViewController as? UITabBarController {
            topViewController = tabBarController.selectedViewController
        }

        if let navigationController = topViewController as? UINavigationController {
            topViewController = navigationController.viewControllers.last
        }

        return topViewController
    }

    public func logout() {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        NotificationCenter.default.removeObserver(self, name: .unauthorizedError, object: nil)

        Task { @MainActor in
            performLogout()
        }
    }

    @MainActor
    private func performLogout() {
        NotificationCenter.default.removeObserver(self, name: .unauthorizedError, object: nil)
        childCoordinators.removeAll()
        showAuthFlow()
    }
}

// MARK: - CoordinatorFinishDelegate
extension AppCoordinator: CoordinatorFinishDelegate {
    public func coordinatorDidFinish(childCoordinator: Coordinator) {
        removeChildCoordinator(childCoordinator)

        if childCoordinator is AuthCoordinator {
            isLoggingOut = false
            setupNotifications()
            showMainFlow()
        }
    }
}
