//
//  ChatRoomResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

struct ChatRoomResponseDTO: Decodable {

    /// 채팅방 고유 ID
    let roomId: String

    /// 채팅방 생성 시간 (UTC, ISO 8601)
    let createdAt: String

    /// 채팅방 업데이트 시간 (마지막 메시지 시간)
    let updatedAt: String

    /// 참여자 배열 (1:1 채팅이므로 항상 2명: 나 + 상대방)
    let participants: [CreatorDTO]

    /// 마지막 채팅 메시지
    let lastChat: ChatMessageResponseDTO?

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case createdAt
        case updatedAt
        case participants
        case lastChat
    }
}
