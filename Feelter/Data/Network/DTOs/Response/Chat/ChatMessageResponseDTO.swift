//
//  ChatMessageResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

struct ChatMessageResponseDTO: Decodable {

    // MARK: - Properties
    /// 메시지 고유 ID (서버 생성)
    let chatId: String

    /// 채팅방 ID
    let roomId: String

    /// 메시지 내용 (이미지만 보낼 경우 빈 문자열)
    let content: String

    /// 메시지 생성 시간 (UTC, ISO 8601)
    let createdAt: String

    /// 메시지 업데이트 시간
    let updatedAt: String?

    /// 발신자 정보
    let sender: CreatorDTO

    /// 첨부 파일 URL 배열
    let files: [String]?
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case roomId = "room_id"
        case content
        case createdAt
        case updatedAt
        case sender
        case files
    }
}

// MARK: - Convenience
extension ChatMessageResponseDTO {
    /// 파일 URL 배열 (nil-safe, 빈 문자열 필터링)
    /// 서버에서 빈 문자열이 포함된 배열을 보낼 수 있으므로 필터링 필요
    var filesArray: [String] {
        return files?.filter { !$0.isEmpty } ?? []
    }
}
