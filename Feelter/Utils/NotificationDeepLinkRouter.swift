//
//  NotificationDeepLinkRouter.swift
//  Feelter
//
//  Created by Claude on 1/18/26.
//

import UIKit

/// 푸시 알림 딥링크 라우팅 처리
///
/// AppDelegate와 SceneDelegate에서 푸시 알림을 받았을 때
/// 해당 채팅방으로 이동하는 로직을 담당합니다.
final class NotificationDeepLinkRouter {

    /// 푸시 알림의 userInfo에서 roomId를 추출하여 SceneDelegate로 라우팅
    ///
    /// - Parameters:
    ///   - userInfo: 푸시 알림의 userInfo
    ///   - sceneDelegate: SceneDelegate 인스턴스
    static func routeToChatRoom(from userInfo: [AnyHashable: Any], sceneDelegate: SceneDelegate?) {
        guard let payload = NotificationPayload.from(userInfo: userInfo),
              let roomId = payload.roomId else {
            return
        }

        // SceneDelegate를 통해 AppCoordinator로 전달
        sceneDelegate?.handlePushDeepLink(roomId: roomId)
    }
}
