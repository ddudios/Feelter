//
//  AppDelegate.swift
//  Feelter
//
//  Created by Suji Jang on 12/10/25.
//

import UIKit
import FirebaseCore
import FirebaseMessaging

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
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
        // TODO: 로그인 상태 확인 필요

        // TODO: 서버에 디바이스 토큰 업데이트 API 호출
        print("FCM 토큰 서버 업데이트 필요: \(token)")
    }
}
