//
//  AppCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import UIKit

// 앱 전체 flow를 관리하는 최상위 Coordinator
final public class AppCoordinator: Coordinator {
    
    // MARK: - Properties
    public var childCoordinators: [Coordinator] = []
    public var navigationController: UINavigationController
    
    // MARK: - Init
    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    // MARK: - Public Methods
    public func start() {
        let isLoggedIn = checkLoginStatus()
        
        if isLoggedIn {
            showMainFlow()
        } else {
            showAuthFlow()
        }
    }
    
    // MARK: - Private Methods
    private func checkLoginStatus() -> Bool {
        // UserDefaults, Keychain 등에서 확인
        return false
    }
    
    private func showAuthFlow() {
        let authCoordinator = AuthCoordinator(navigationController: navigationController)
        authCoordinator.finishDelegate = self
        addChildCoordinator(authCoordinator)
        authCoordinator.start()
    }
    
    private func showMainFlow() {
        let homeVC = HomeViewController()
        
        // setViewControllers를 사용해 네비게이션 스택을 완전히 교체(뒤로가기 방지)
        navigationController.setViewControllers([homeVC], animated: true)
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
