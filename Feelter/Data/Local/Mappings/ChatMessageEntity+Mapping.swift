//
//  ChatMessageEntity+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import Foundation
import CoreData

extension ChatMessageEntity {

    /// CoreData Entity -> Domain Entity로 변환
    ///
    /// 변환 작업:
    /// 1. files: Transformable로 자동 변환된 [String] 그대로 사용
    /// 2. status: String -> MessageSendStatus enum
    /// 3. 나머지 프로퍼티는 그대로 복사
    ///
    /// - Returns: ChatMessage (Domain Entity)
    /// - Note: files는 이제 Transformable 타입으로 자동 변환되므로 별도 파싱 불필요
    func toDomain() -> ChatMessage {
        // 1. files는 이미 [String]? 타입 (Transformable로 자동 변환)
        let filesArray = (self.files as? [String]) ?? []

        // 2. status 변환 (String -> Enum)
        let messageStatus = MessageSendStatus(rawValue: self.status ?? "") ?? .sent

        // 3. ChatMessage 생성
        return ChatMessage(
            chatId: self.chatId ?? "",
            roomId: self.roomId ?? "",
            content: self.content ?? "",
            senderId: self.senderId ?? "",
            senderNick: self.senderNick ?? "",
            senderProfileImage: self.senderProfileImage,
            createdAt: self.createdAt ?? Date(),
            files: filesArray,
            status: messageStatus
        )
    }
}
