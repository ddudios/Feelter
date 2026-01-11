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
    /// 1. files: JSON String -> [String] 배열
    /// 2. status: String -> MessageSendStatus enum
    /// 3. 나머지 프로퍼티는 그대로 복사
    ///
    /// - Returns: ChatMessage (Domain Entity)
    func toDomain() -> ChatMessage {
        // 1. files 변환 (JSON String -> Array)
        let filesArray = parseFilesJSON(self.files)

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

    /// JSON String을 [String] 배열로 파싱
    ///
    /// CoreData에는 다음과 같은 형태로 저장되어 있음:
    /// ```
    /// "[\"file1.jpg\", \"file2.png\"]"
    /// ```
    ///
    /// - Parameter jsonString: JSON 형식의 String
    /// - Returns: 파일 경로 배열 (파싱 실패 시 빈 배열)
    private func parseFilesJSON(_ jsonString: String?) -> [String] {
        // 1. nil이거나 빈 문자열이면 빈 배열 반환
        guard let jsonString = jsonString, !jsonString.isEmpty else {
            return []
        }

        // 2. JSON 파싱
        guard let data = jsonString.data(using: .utf8) else {
            print("files JSON String을 Data로 변환 실패: \(jsonString)")
            return []
        }

        do {
            // 3. JSONDecoder로 [String] 디코딩
            let files = try JSONDecoder().decode([String].self, from: data)
            return files
        } catch {
            print("files JSON 파싱 실패: \(error.localizedDescription)")
            return []
        }
    }
}
