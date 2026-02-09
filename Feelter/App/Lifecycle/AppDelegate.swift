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

        // Firebase 초기화 (Info.plist에서 Analytics/Crashlytics는 비활성화됨)
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
            completionHandler(presentationOptions())
            return
        }

        // UI 상태 확인 (iOS 16+에서는 Scene을 통해 접근)
        if let currentChatRoomId = getCurrentVisibleChatRoomId() {
            if currentChatRoomId == pushRoomId {
                // 동일 채팅방이면 알림 생략
                completionHandler([])
            } else {
                // 다른 채팅방의 메시지 수신 → 배지 카운팅 증가
                notifyNewMessageReceived(roomId: pushRoomId)
                completionHandler(presentationOptions())
            }
        } else {
            // ChatRoomList 또는 다른 화면에 있을 때 → 배지 카운팅 증가
            notifyNewMessageReceived(roomId: pushRoomId)
            completionHandler(presentationOptions())
        }
    }

    /// iOS 버전에 맞는 알림 표시 옵션 반환
    private func presentationOptions() -> UNNotificationPresentationOptions {
        if #available(iOS 14.0, *) {
            return [.banner, .list, .sound, .badge]
        } else {
            return [.alert, .sound, .badge]
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

    /// 새 메시지 수신 알림 발송 (ChatRoomList 배지 카운팅용)
    ///
    /// ChatRoomList에서 구독하여 해당 채팅방의 배지 카운트 +1
    /// - Parameter roomId: 메시지를 받은 채팅방 ID
    private func notifyNewMessageReceived(roomId: String) {
        NotificationCenter.default.post(
            name: .newMessageReceived,
            object: nil,
            userInfo: ["roomId": roomId]
        )
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

    /// Data-only 메시지 수신 (포그라운드/백그라운드 모두)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // data-only 메시지인 경우 수동으로 로컬 푸시 생성
        if userInfo["gcm.message_id"] != nil {
            // FCM data 메시지
            showLocalNotification(from: userInfo)

            // 배지 카운팅 증가 (백그라운드에서 푸시 수신 시)
            if let payload = NotificationPayload.from(userInfo: userInfo),
               let roomId = payload.roomId {
                notifyNewMessageReceived(roomId: roomId)
            }
        }

        completionHandler(.newData)
    }

    /// 로컬 푸시 생성 (data-only 메시지용)
    private func showLocalNotification(from userInfo: [AnyHashable: Any]) {
        // 같은 채팅방에 있으면 푸시 안 보냄
        if let payload = NotificationPayload.from(userInfo: userInfo),
           let pushRoomId = payload.roomId,
           let currentChatRoomId = getCurrentVisibleChatRoomId(),
           currentChatRoomId == pushRoomId {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = (userInfo["title"] as? String) ?? "새 메시지"
        content.body = (userInfo["body"] as? String) ?? "새로운 채팅 메시지가 도착했습니다."
        content.sound = .default
        content.badge = (userInfo["badge"] as? NSNumber) ?? 1
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // 즉시 표시
        )

        UNUserNotificationCenter.current().add(request)
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
