//
//  ChatHistoryResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/14/26.
//

import Foundation

/// 채팅 내역 조회 응답 DTO
/// GET /v1/chats/{room_id}
struct ChatHistoryResponseDTO: Decodable {
    /// 채팅 메시지 배열 (생성 시간 기준 오래된 순)
    let data: [ChatMessageResponseDTO]
}
