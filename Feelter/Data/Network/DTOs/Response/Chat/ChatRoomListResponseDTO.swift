//
//  ChatRoomListResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

struct ChatRoomListResponseDTO: Decodable {

    /// 채팅방 배열 (updatedAt 기준 최신순)
    let data: [ChatRoomResponseDTO]
}
