//
//  CreateChatRoomRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

struct CreateChatRoomRequestDTO: Encodable {
    /// 채팅 상대방 User ID
    let opponentId: String
    
    enum CodingKeys: String, CodingKey {
        case opponentId = "opponent_id" // Swift(Camel) -> JSON(Snake) 변환
    }
}
