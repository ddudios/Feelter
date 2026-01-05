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

    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

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
    
    private func showAuthFlow() {
        let authCoordinator = AuthCoordinator(navigationController: navigationController)
        authCoordinator.finishDelegate = self
        addChildCoordinator(authCoordinator)
        authCoordinator.start()
    }
    
    private func showMainFlow() {
        let tabBarCoordinator = TabBarCoordinator(navigationController: navigationController)
        addChildCoordinator(tabBarCoordinator)
        tabBarCoordinator.start()
    }

    @objc private func handleUnauthorizedError() {
        logout()
    }

    private func logout() {
        // 키체인에서 토큰 삭제
        KeychainManager.shared.delete(account: "accessToken")
        KeychainManager.shared.delete(account: "refreshToken")

        // 자식 코디네이터 모두 제거
        childCoordinators.removeAll()

        // 로그인 화면으로 이동
        showAuthFlow()
    }
}

// MARK: - CoordinatorFinishDelegate
extension AppCoordinator: CoordinatorFinishDelegate {
    public func coordinatorDidFinish(childCoordinator: Coordinator) {
        // 1. 메모리에서 제거
        removeChildCoordinator(childCoordinator)
        
        // 2. 다음 Flow로 전환 (로그인 완료 -> 메인 화면)
        if childCoordinator is AuthCoordinator {
            showMainFlow()
        }
    }
}
