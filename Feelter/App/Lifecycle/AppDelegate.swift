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
import iamport_ios
import KakaoSDKCommon
import KakaoSDKAuth

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Kakao SDK 초기화
        let kakaoAppKey = Config.kakaoLoginKey
        KakaoSDK.initSDK(appKey: kakaoAppKey)

        // Firebase 초기화
        FirebaseApp.configure()
        
        // 권한에 대한 세팅
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        application.registerForRemoteNotifications()  // 원격 알림 쓸거야
        
        // Messaging delegate 설정: 서버 대신
        Messaging.messaging().delegate = self
        
        // 현재 등록 토큰 가져오기
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error fetching FCM registration token: \(error)")
            } else if let token = token {
                print("FCM registration token: \(token)")  // 이게 파베가 쓰기 편한 코드임
            }
        }
        
        // 전역 설정: 모든 Kingfisher 요청에 이 Modifier가 적용됨
        KingfisherManager.shared.defaultOptions = [
            .requestModifier(AuthHeaderModifier())
        ]
        
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        Messaging.messaging().apnsToken = deviceToken
        print("APNs token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        print("APNs 등록 실패: \(error)")
    }

    /// 포그라운드에서 푸시 알림 수신 시 호출
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        // 푸시 알림에서 roomId 추출
        guard let payload = NotificationPayload.from(userInfo: userInfo),
              let pushRoomId = payload.roomId else {
            // roomId가 없으면 기본 동작 (배너 표시)
            completionHandler([.banner, .sound, .badge])
            return
        }

        // 현재 표시 중인 채팅방 확인
        if let currentChatRoomId = getCurrentVisibleChatRoomId() {
            if currentChatRoomId == pushRoomId {
                // 현재 보고 있는 채팅방의 푸시 알림은 표시하지 않음
                completionHandler([])
            } else {
                // 다른 채팅방의 푸시 알림은 표시
                completionHandler([.banner, .sound, .badge])
            }
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }

    /// 현재 화면에 표시 중인 ChatRoomViewController의 roomId 반환
    ///
    /// - Returns: 현재 표시 중인 채팅방 ID (없으면 nil)
    private func getCurrentVisibleChatRoomId() -> String? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }

        // 최상위 ViewController 찾기
        var topViewController = rootViewController

        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }

        // TabBarController인 경우 선택된 ViewController 확인
        if let tabBarController = topViewController as? UITabBarController {
            topViewController = tabBarController.selectedViewController ?? topViewController
        }

        // NavigationController인 경우 최상위 ViewController 확인
        if let navigationController = topViewController as? UINavigationController {
            topViewController = navigationController.viewControllers.last ?? topViewController

            // TabBarController 안의 NavigationController인 경우 다시 확인
            if let tabBarController = topViewController as? UITabBarController {
                topViewController = tabBarController.selectedViewController ?? topViewController

                // 다시 NavigationController 확인
                if let innerNavController = topViewController as? UINavigationController {
                    topViewController = innerNavController.viewControllers.last ?? topViewController
                }
            }
        }

        // ChatRoomViewController인지 확인하고 roomId 반환
        if let chatRoomVC = topViewController as? ChatRoomViewController {
            let roomId = chatRoomVC.getCurrentChatRoomId()
            return roomId
        }

        return nil
    }

    /// 푸시 알림 탭 시 호출
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // SceneDelegate를 통해 딥링크 처리
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate {
            NotificationDeepLinkRouter.routeToChatRoom(from: userInfo, sceneDelegate: sceneDelegate)
        }

        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    // 디바이스 토큰 정보가 변경이 되면 알려줌
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")

        guard let token = fcmToken else { return }

        // NotificationCenter로 토큰 전파 (필요시 사용)
        let dataDict: [String: String] = ["token": token]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )

        // 토큰 변경 시 서버에 업데이트
        Task {
            await updateDeviceTokenToServer(token)
        }
    }

    private func updateDeviceTokenToServer(_ token: String) async {
        // 로그인 상태 확인 (accessToken이 없으면 API 호출 불가)
        guard let accessToken = KeychainManager.shared.read(account: "accessToken"),
              !accessToken.isEmpty else {
            return
        }

        // 서버에 디바이스 토큰 업데이트 API 호출
        do {
            let requestDTO = DeviceTokenUpdateRequestDTO(deviceToken: token)
            let networkManager = NetworkManager()
            try await networkManager.requestWithEmptyResponse(
                UserRouter.updateDeviceToken(body: requestDTO)
            )
        } catch {
        }
    }

    // FCM 포그라운드 메시지 수신 (선택사항)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        print("🔥 [AppDelegate] didReceiveRemoteNotification 호출됨 (백그라운드)")
        print("🔥 [AppDelegate] userInfo: \(userInfo)")
        return .newData
    }
}

extension AppDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // 카카오 로그인 URL 처리
        if AuthApi.isKakaoTalkLoginUrl(url) {
            return AuthController.handleOpenUrl(url: url)
        }

        // 아임포트 결제 URL 처리
        Iamport.shared.receivedURL(url)
        return true
    }
}
