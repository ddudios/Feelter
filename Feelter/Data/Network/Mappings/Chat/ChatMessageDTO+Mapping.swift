//
//  ChatMessageDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

extension ChatMessageResponseDTO {

    /// DTO를 Domain Entity로 변환
    ///
    /// 변환 작업:
    /// 1. ISO 8601 String -> Date
    /// 2. CreatorDTO -> sender 정보 추출
    /// 3. Optional 처리 (files)
    /// 4. status 기본값 설정 (.sent)
    ///
    /// - Returns: ChatMessage (Domain Entity)
    func toDomain() -> ChatMessage {
        // 1. 날짜 변환
        let createdDate = ISO8601DateParser.date(from: createdAt)

        // 2. 발신자 정보 추출
        let senderId = sender.userId
        let senderNick = sender.nick
        let senderProfileImage = sender.profileImage

        // 3. 파일 배열 (nil-safe)
        let filesArray = self.filesArray

        // 4. ChatMessage 생성
        return ChatMessage(
            chatId: chatId,
            roomId: roomId,
            content: content,
            senderId: senderId,
            senderNick: senderNick,
            senderProfileImage: senderProfileImage,
            createdAt: createdDate,
            files: filesArray,
            status: .sent // API 응답은 항상 전송 완료 상태
        )
    }
}
