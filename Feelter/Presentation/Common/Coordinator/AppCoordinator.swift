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
    private var pendingChatRoomId: String?  // 로그인 전 대기 중인 채팅방 ID

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePendingPaymentDetected),
            name: .pendingPaymentDetected,
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

    @objc private func handlePendingPaymentDetected(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let filterId = userInfo["filterId"] as? String,
              let orderCode = userInfo["orderCode"] as? String,
              let totalPrice = userInfo["totalPrice"] as? Int else {
            return
        }

        Task { @MainActor in
            showPendingPaymentAlert(filterId: filterId, orderCode: orderCode, totalPrice: totalPrice)
        }
    }

    @MainActor
    private func showPendingPaymentAlert(filterId: String, orderCode: String, totalPrice: Int) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let priceString = formatter.string(from: NSNumber(value: totalPrice)) ?? "\(totalPrice)"

        let alert = UIAlertController(
            title: "미완료 결제",
            message: "결제가 완료되지 않은 주문이 있습니다.\n주문번호: \(orderCode)\n금액: \(priceString)원\n\n해당 필터로 이동하여 결제를 진행하시겠습니까?",
            preferredStyle: .alert
        )

        let retryAction = UIAlertAction(title: "이동", style: .default) { [weak self] _ in
            // Alert dismiss 후 navigation 수행 (중복 탭 방지)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.navigateToFilterDetail(filterId: filterId)
            }
        }

        let cancelAction = UIAlertAction(title: "취소", style: .cancel) { _ in
            // 사용자가 취소하면 저장된 결제 상태 삭제
            PaymentStateManager.shared.clearPendingPayment()
        }

        alert.addAction(retryAction)
        alert.addAction(cancelAction)

        // 최상위 ViewController에서 알림 표시
        if let topViewController = getTopViewController() {
            topViewController.present(alert, animated: true)
        }
    }

    @MainActor
    private func navigateToFilterDetail(filterId: String) {
        // TabBarCoordinator를 찾아서 필터 상세로 이동
        if let tabBarCoordinator = childCoordinators.first(where: { $0 is TabBarCoordinator }) as? TabBarCoordinator {
            tabBarCoordinator.showFilterDetail(filterId: filterId)
        }
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

            // 로그인 완료 후 대기 중인 채팅방이 있으면 이동
            if let roomId = pendingChatRoomId {
                pendingChatRoomId = nil
                handleChatDeepLink(roomId: roomId)
            }
        }
    }
}

// MARK: - Deep Link Handling
extension AppCoordinator {
    /// 푸시 알림을 통한 채팅방 딥링크 처리
    ///
    /// - Parameter roomId: 이동할 채팅방 ID
    ///
    /// 동작:
    /// 1. 로그인 상태 확인
    /// 2. 로그인 상태:
    ///    - TabBarCoordinator를 찾아서 채팅방으로 이동
    /// 3. 미로그인 상태:
    ///    - pendingChatRoomId에 저장 후 로그인 완료 시 이동
    public func handleChatDeepLink(roomId: String) {
        // 로그인 상태 확인
        let isLoggedIn = checkLoginStatus()

        if isLoggedIn {
            // TabBarCoordinator를 찾아서 채팅방으로 이동
            if let tabBarCoordinator = childCoordinators.first(where: { $0 is TabBarCoordinator }) as? TabBarCoordinator {
                tabBarCoordinator.showChatRoom(roomId: roomId)
            } else {
                // TabBarCoordinator가 아직 준비되지 않은 경우 잠시 대기 후 재시도
                pendingChatRoomId = roomId
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    if let roomId = self?.pendingChatRoomId {
                        self?.pendingChatRoomId = nil
                        self?.handleChatDeepLink(roomId: roomId)
                    }
                }
            }
        } else {
            // 미로그인 상태: 로그인 후 이동하도록 대기
            pendingChatRoomId = roomId
        }
    }
}
