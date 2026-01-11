//
//  ChatRoomDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

extension ChatRoomResponseDTO {

    /// DTO를 Domain Entity로 변환
    ///
    /// 변환 작업:
    /// 1. ISO 8601 String -> Date
    /// 2. participants에서 상대방 찾기 (내 ID 제외)
    /// 3. CreatorDTO -> ChatRoom.Opponent 변환
    /// 4. lastChat이 있으면 ChatMessage로 변환
    ///
    /// - Parameter currentUserId: 현재 로그인한 사용자 ID
    /// - Returns: ChatRoom (Domain Entity)
    /// - Note: 상대방을 찾지 못하면 fatalError (1:1 채팅이므로 항상 있어야 함)
    func toDomain(currentUserId: String) -> ChatRoom {
        // 1. 날짜 변환
        let createdDate = ISO8601DateParser.date(from: createdAt)
        let updatedDate = ISO8601DateParser.date(from: updatedAt)

        // 2. 상대방 찾기
        // participants = [나, 상대방]
        // 내 ID를 제외한 사람이 상대방
        guard let opponentDTO = participants.first(where: { $0.userId != currentUserId }) else {
            // 1:1 채팅이므로 상대방은 항상 있어야 함
            fatalError("ChatRoom participants에서 상대방을 찾을 수 없습니다. participants: \(participants)")
        }

        // 3. CreatorDTO -> ChatRoom.Opponent 변환
        let opponent = ChatRoom.Opponent(
            userId: opponentDTO.userId,
            nick: opponentDTO.nick,
            profileImage: opponentDTO.profileImage
        )

        // 4. lastChat 변환 (있으면)
        let lastMessage: ChatMessage? = lastChat?.toDomain()

        // 5. ChatRoom 생성
        return ChatRoom(
            roomId: roomId,
            createdAt: createdDate,
            updatedAt: updatedDate,
            opponent: opponent,
            lastMessage: lastMessage,
            lastReadAt: nil // 로컬에서만 관리하는 값 (서버에서 주지 않음)
        )
    }
}
