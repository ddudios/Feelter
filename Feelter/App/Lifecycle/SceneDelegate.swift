//
//  SceneDelegate.swift
//  Feelter
//
//  Created by Suji Jang on 12/10/25.
//

import UIKit
import KakaoSDKAuth
import iamport_ios

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // 1. 초기 인프라 설정
        StringArrayValueTransformer.register()
        registerDependencies()

        // 2. Coordinator & Window 설정
        let navigationController = UINavigationController()
        appCoordinator = AppCoordinator(navigationController: navigationController)
        appCoordinator?.start()

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()

        // 3. 콜드 스타트(앱 종료 상태)에서 알림으로 진입한 경우
        if let response = connectionOptions.notificationResponse {
            let userInfo = response.notification.request.content.userInfo
            if let payload = NotificationPayload.from(userInfo: userInfo), let roomId = payload.roomId {
                // UI 로딩 대기 후 이동
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.handlePushDeepLink(roomId: roomId)
                }
            }
        }
    }

    // MARK: - 외부 유입 (URL Scheme) 처리
    // 카카오 로그인, 아임포트 결제 결과 등 앱 외부에서 들어오는 모든 URL을 통합 관리합니다.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        #if DEBUG
        print("✅ [SceneDelegate] URL Scheme 수신: \(url.absoluteString)")
        #endif

        // 1. 카카오 로그인 리다이렉트 처리
        if AuthApi.isKakaoTalkLoginUrl(url) {
            _ = AuthController.handleOpenUrl(url: url)
            return
        }

        // 2. 아임포트 결제 콜백 처리 (기존 AppDelegate에서 이동)
        Iamport.shared.receivedURL(url)

        #if DEBUG
        print("✅ [SceneDelegate] 아임포트로 URL 전달 완료")
        #endif
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // 백그라운드에서 돌아올 때마다 미완료 결제 체크
        // 단, 결제 진행 중일 때는 체크하지 않음 (중복 알럿 방지)
        checkForPendingPayment()
    }

    private func checkForPendingPayment() {
        // 결제 진행 중이면 알럿 표시 안 함
        guard !PaymentStateManager.shared.isPaymentInProgress() else { return }

        guard let pending = PaymentStateManager.shared.getPendingPayment() else { return }
        NotificationCenter.default.post(name: .pendingPaymentDetected, object: nil, userInfo: [
            "filterId": pending.filterId,
            "orderCode": pending.orderCode,
            "totalPrice": pending.totalPrice
        ])
    }

    // Coordinator를 통한 딥링크 이동
    func handlePushDeepLink(roomId: String) {
        appCoordinator?.handleChatDeepLink(roomId: roomId)
    }
}
