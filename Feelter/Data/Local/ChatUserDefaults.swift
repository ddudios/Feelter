//
//  ChatUserDefaults.swift
//  Feelter
//
//  Created by Claude on 2/9/26.
//

import Foundation

/// 채팅 관련 UserDefaults 관리
/// - 마지막으로 읽은 메시지 ID 저장/조회
final class ChatUserDefaults {

    static let shared = ChatUserDefaults()

    private init() {}

    // MARK: - Keys
    private func lastReadMessageIdKey(for roomId: String) -> String {
        return "lastReadMessageId_\(roomId)"
    }

    // MARK: - Public Methods

    /// 마지막으로 읽은 메시지 ID 저장
    /// - Parameters:
    ///   - messageId: 메시지 ID
    ///   - roomId: 채팅방 ID
    func saveLastReadMessageId(_ messageId: String, for roomId: String) {
        UserDefaults.standard.set(messageId, forKey: lastReadMessageIdKey(for: roomId))
    }

    /// 마지막으로 읽은 메시지 ID 조회
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: 마지막으로 읽은 메시지 ID (없으면 nil)
    func getLastReadMessageId(for roomId: String) -> String? {
        return UserDefaults.standard.string(forKey: lastReadMessageIdKey(for: roomId))
    }

    /// 모든 채팅방의 마지막 읽은 메시지 ID 조회
    /// - Returns: [roomId: lastReadMessageId] Dictionary
    func getAllLastReadMessageIds() -> [String: String] {
        var result: [String: String] = [:]

        // UserDefaults의 모든 키 중에서 "lastReadMessageId_" 로 시작하는 키만 필터링
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix("lastReadMessageId_") {
            if let value = UserDefaults.standard.string(forKey: key) {
                // "lastReadMessageId_" 제거하여 roomId 추출
                let roomId = String(key.dropFirst("lastReadMessageId_".count))
                result[roomId] = value
            }
        }

        return result
    }

    /// 특정 채팅방의 마지막 읽은 메시지 ID 삭제
    /// - Parameter roomId: 채팅방 ID
    func removeLastReadMessageId(for roomId: String) {
        UserDefaults.standard.removeObject(forKey: lastReadMessageIdKey(for: roomId))
    }

    /// 모든 채팅방의 마지막 읽은 메시지 ID 삭제 (로그아웃 시 사용)
    func removeAllLastReadMessageIds() {
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix("lastReadMessageId_") {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
