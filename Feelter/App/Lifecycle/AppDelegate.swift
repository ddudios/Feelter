//
//  AppDelegate.swift
//  Feelter
//
//  Created by Suji Jang on 12/10/25.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import Kingfisher
import KakaoSDKCommon

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 1. SDK 초기화 (앱 실행 시 최초 1회)
        KakaoSDK.initSDK(appKey: Config.kakaoLoginKey)
        FirebaseApp.configure()
        
        // 2. 알림 권한 설정 및 델리게이트 연결
        setupNotification(application)
        
        // 3. Kingfisher 전역 설정
        KingfisherManager.shared.defaultOptions = [.requestModifier(AuthHeaderModifier())]
        
        return true
    }

    private func setupNotification(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { _, _ in }
        
        application.registerForRemoteNotifications()
    }

    // MARK: - UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

// MARK: - UNUserNotificationCenterDelegate (알림 처리)
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // APNs 토큰 등록 성공 시 FCM에 전달
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // 포그라운드 알림 수신
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        guard let payload = NotificationPayload.from(userInfo: userInfo),
              let pushRoomId = payload.roomId else {
            completionHandler([.banner, .list, .sound, .badge])
            return
        }

        // UI 상태 확인 (iOS 16+에서는 Scene을 통해 접근)
        if let currentChatRoomId = getCurrentVisibleChatRoomId(), currentChatRoomId == pushRoomId {
            // 동일 채팅방이면 알림 생략
            completionHandler([])
        } else {
            completionHandler([.banner, .list, .sound, .badge])
        }
    }

    // 알림 클릭 시 (Deep Link)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // SceneDelegate를 찾아 라우팅 명령 전달
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            NotificationDeepLinkRouter.routeToChatRoom(from: userInfo, sceneDelegate: sceneDelegate)
        }
        completionHandler()
    }

    // 현재 활성화된 채팅방 ID 확인 Helper
    private func getCurrentVisibleChatRoomId() -> String? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              var topVC = window.rootViewController else { return nil }

        while let presented = topVC.presentedViewController { topVC = presented }
        
        // 네비게이션/탭바 내부의 최상위 뷰 탐색 루프
        var current: UIViewController? = topVC
        while true {
            if let nav = current as? UINavigationController { current = nav.viewControllers.last }
            else if let tab = current as? UITabBarController { current = tab.selectedViewController }
            else { break }
        }

        return (current as? ChatRoomViewController)?.getCurrentChatRoomId()
    }
}

// MARK: - MessagingDelegate (FCM 토큰 관리)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        
        Task {
            await updateDeviceTokenToServer(token)
        }
    }

    private func updateDeviceTokenToServer(_ token: String) async {
        guard let accessToken = KeychainManager.shared.read(account: "accessToken"), !accessToken.isEmpty else { return }
        
        do {
            let networkManager = NetworkManager()
            try await networkManager.requestWithEmptyResponse(UserRouter.updateDeviceToken(body: .init(deviceToken: token)))
        } catch {
            print("Token update failed: \(error)")
        }
    }
}
