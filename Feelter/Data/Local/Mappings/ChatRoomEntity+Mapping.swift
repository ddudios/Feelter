//
//  ChatRoomEntity+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import Foundation
import CoreData

extension ChatRoomEntity {

    /// CoreData Entity -> Domain Entity로 변환
    ///
    /// 변환 작업:
    /// 1. 상대방 정보 (opponentUserId, opponentNick, opponentProfileImage) -> ChatRoom.Opponent
    /// 2. messages Relationship에서 가장 최신 메시지 가져오기
    /// 3. 나머지 프로퍼티 복사
    ///
    /// - Returns: ChatRoom (Domain Entity)
    func toDomain() -> ChatRoom {
        // 1. Opponent 생성
        let opponent = ChatRoom.Opponent(
            userId: self.opponentUserId ?? "",
            nick: self.opponentNick ?? "알 수 없음",
            profileImage: self.opponentProfileImage
        )

        // 2. lastMessage 가져오기
        // messages Relationship에서 createdAt 기준 최신 메시지 1개
        let lastMessage = getLastMessage()

        // 3. ChatRoom 생성
        return ChatRoom(
            roomId: self.roomId ?? "",
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date(),
            opponent: opponent,
            lastMessage: lastMessage,
            lastReadAt: self.lastReadAt
        )
    }

    // MARK: - Private Helpers
    /// messages Relationship에서 가장 최신 메시지 가져오기
    ///
    /// CoreData Relationship:
    /// - ChatRoomEntity <-> ChatMessageEntity (one-to-many)
    /// - ChatRoomEntity의 messages 속성에서 가져옴
    ///
    /// - Returns: ChatMessage? (메시지가 없으면 nil)
    private func getLastMessage() -> ChatMessage? {
        // 1. messages Relationship에서 NSSet -> [ChatMessageEntity] 변환
        guard let messagesSet = self.messages as? Set<ChatMessageEntity> else {
            return nil
        }

        // 2. createdAt 기준 정렬 (최신순)
        let sortedMessages = messagesSet.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }

        // 3. 가장 최신 메시지 가져오기
        guard let latestMessageEntity = sortedMessages.first else {
            return nil
        }

        // 4. Domain Entity로 변환
        return latestMessageEntity.toDomain()
    }
}
