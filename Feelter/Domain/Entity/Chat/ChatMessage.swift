//
//  ChatMessage.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

struct ChatMessage: Equatable, Hashable, Identifiable {

    // MARK: - Properties
    /// 메시지 고유 ID (서버 생성)
    let chatId: String

    /// 채팅방 ID
    let roomId: String

    /// 메시지 내용
    let content: String

    /// 발신자 ID
    let senderId: String

    /// 발신자 닉네임
    let senderNick: String

    /// 발신자 프로필 이미지 URL
    let senderProfileImage: String?

    /// 메시지 생성 시간 (서버 시간)
    let createdAt: Date

    /// 첨부 파일 URL 배열
    let files: [String]

    /// 전송 상태 (로컬에서만 관리) - 서버에서는 내려주지 않는 값
    /// 클라이언트에서 메시지 전송 시:
    /// 1. .sending 상태로 생성
    /// 2. API 성공 시 .sent로 변경
    /// 3. API 실패 시 .failed로 변경
    var status: MessageSendStatus

    // MARK: - Identifiable
    /// Identifiable 프로토콜 요구사항
    /// SwiftUI List에서 id로 사용됨
    var id: String { chatId }

    // MARK: - Computed Properties
    /// 메시지가 첨부 파일을 포함하는지 여부
    var hasFiles: Bool {
        return !files.isEmpty
    }

    /// 메시지 전송 실패 여부
    var isFailed: Bool {
        return status == .failed
    }

    /// 메시지 전송 중 여부
    var isSending: Bool {
        return status == .sending
    }
}

// MARK: - Factory Methods
extension ChatMessage {

    /// 로컬 메시지 생성용 (전송 전)
    ///
    /// 사용자가 메시지 입력 후 전송 버튼을 누를 때 사용
    /// chatId는 UUID로 임시 생성 -> 서버 응답 받으면 실제 ID로 교체
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    ///   - content: 메시지 내용
    ///   - senderId: 내 ID
    ///   - senderNick: 내 닉네임
    ///   - senderProfileImage: 내 프로필 이미지
    ///   - files: 첨부 파일
    /// - Returns: 전송 중 상태의 메시지
    static func createLocal(
        roomId: String,
        content: String,
        senderId: String,
        senderNick: String,
        senderProfileImage: String? = nil,
        files: [String] = []
    ) -> ChatMessage {
        return ChatMessage(
            chatId: UUID().uuidString, // 임시 ID
            roomId: roomId,
            content: content,
            senderId: senderId,
            senderNick: senderNick,
            senderProfileImage: senderProfileImage,
            createdAt: Date(), // 현재 시간
            files: files,
            status: .sending // 전송 중 상태
        )
    }
}

// MARK: - Helper Methods
extension ChatMessage {

    /// 메시지 상태 변경
    /// struct는 불변이므로 새로운 인스턴스 반환
    ///
    /// - Parameter newStatus: 새로운 상태
    /// - Returns: 상태가 변경된 새 메시지
    func with(status newStatus: MessageSendStatus) -> ChatMessage {
        return ChatMessage(
            chatId: chatId,
            roomId: roomId,
            content: content,
            senderId: senderId,
            senderNick: senderNick,
            senderProfileImage: senderProfileImage,
            createdAt: createdAt,
            files: files,
            status: newStatus
        )
    }

    /// 서버에서 받은 실제 ID로 업데이트
    /// 로컬에서 UUID로 생성한 메시지를 서버 ID로 교체
    ///
    /// - Parameter serverChatId: 서버에서 생성한 실제 ID
    /// - Returns: ID가 업데이트된 새 메시지
    func with(serverChatId: String) -> ChatMessage {
        return ChatMessage(
            chatId: serverChatId,
            roomId: roomId,
            content: content,
            senderId: senderId,
            senderNick: senderNick,
            senderProfileImage: senderProfileImage,
            createdAt: createdAt,
            files: files,
            status: .sent // 서버 응답 받았으므로 전송 완료
        )
    }
}
