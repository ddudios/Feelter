//
//  NotificationPayload.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation

/// 푸시 알림 페이로드 파싱 구조체
///
/// FCM/APNs에서 전달받은 userInfo로부터 필요한 데이터를 추출합니다.
struct NotificationPayload {
    let roomId: String?

    /// userInfo에서 NotificationPayload 생성
    ///
    /// - Parameter userInfo: UNNotification의 userInfo
    /// - Returns: 파싱된 NotificationPayload (roomId가 없으면 nil)
    static func from(userInfo: [AnyHashable: Any]) -> NotificationPayload? {
        // roomId 추출 시도
        // 백엔드가 room_id (snake_case)로 보낼 수도 있고, roomId (camelCase)로 보낼 수도 있음
        var roomId: String?

        // 1. 먼저 room_id로 시도 (snake_case)
        if let id = userInfo["room_id"] as? String {
            roomId = id
        }
        // 2. roomId로 시도 (camelCase)
        else if let id = userInfo["roomId"] as? String {
            roomId = id
        }
        // 3. FCM의 경우 data payload 안에 있을 수 있음
        else if let data = userInfo["data"] as? [String: Any],
                let id = data["room_id"] as? String {
            roomId = id
        }
        else if let data = userInfo["data"] as? [String: Any],
                let id = data["roomId"] as? String {
            roomId = id
        }

        // roomId가 없으면 nil 반환
        guard let roomId = roomId else {
            return nil
        }

        return NotificationPayload(roomId: roomId)
    }
}
