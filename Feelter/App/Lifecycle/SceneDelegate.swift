//
//  SceneDelegate.swift
//  Feelter
//
//  Created by Suji Jang on 12/10/25.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // CoreData ValueTransformer 등록 (앱 시작 시 한 번만)
        StringArrayValueTransformer.register()

        registerDependencies()

        let navigationController = UINavigationController()
        appCoordinator = AppCoordinator(navigationController: navigationController)
        appCoordinator?.start()

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // 앱이 활성화될 때 미완료 결제 확인
        checkForPendingPayment()
    }

    /// 미완료 결제 확인 및 알림
    private func checkForPendingPayment() {
        guard let pendingPayment = PaymentStateManager.shared.getPendingPayment() else {
            return
        }

        // 미완료 결제가 있으면 알림 발송
        // 앱의 다른 부분에서 이 노티피케이션을 수신하여 적절히 처리할 수 있음
        NotificationCenter.default.post(
            name: .pendingPaymentDetected,
            object: nil,
            userInfo: [
                "filterId": pendingPayment.filterId,
                "orderCode": pendingPayment.orderCode,
                "totalPrice": pendingPayment.totalPrice
            ]
        )
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

