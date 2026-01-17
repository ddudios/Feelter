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
        // 1. files 안전하게 변환
        var filesArray: [String] = []
        if let files = self.files {
            // Transformable로 저장된 데이터를 [String]으로 변환
            if let stringArray = files as? [String] {
                filesArray = stringArray.filter { !$0.isEmpty }
            } else if let anyArray = files as? [Any] {
                // 혹시 Any 타입으로 저장되었을 경우 대비
                filesArray = anyArray.compactMap { $0 as? String }.filter { !$0.isEmpty }
            } else {
            }
        }

        // 2. status 변환 (String -> Enum)
        let messageStatus = MessageSendStatus(rawValue: self.status ?? "") ?? .sent

        // 3. ChatMessage 생성
        let contentValue = self.content?.isEmpty == false ? self.content : nil

        return ChatMessage(
            chatId: self.chatId ?? "",
            roomId: self.roomId ?? "",
            content: contentValue,
            senderId: self.senderId ?? "",
            senderNick: self.senderNick ?? "",
            senderProfileImage: self.senderProfileImage,
            createdAt: self.createdAt ?? Date(),
            files: filesArray,
            status: messageStatus
        )
    }
}
