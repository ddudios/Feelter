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
        Task { @MainActor in
            performLogout()
        }
    }

    public func logout() {
        // 로그아웃 중복 호출 방지
        NotificationCenter.default.removeObserver(self, name: .unauthorizedError, object: nil)

        // 화면 전환만 수행 (비즈니스 로직은 ViewModel에서 이미 처리됨)
        Task { @MainActor in
            performLogout()
        }
    }

    @MainActor
    private func performLogout() {
        // 자식 코디네이터 모두 제거
        childCoordinators.removeAll()
    
        // 로그인 화면으로 완전히 교체
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
