//
//  ChatRoom.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

struct ChatRoom: Equatable, Hashable, Identifiable {

    // MARK: - Properties
    /// 채팅방 고유 ID
    let roomId: String

    /// 채팅방 생성 시간
    let createdAt: Date

    /// 채팅방 업데이트 시간 (마지막 메시지 시간)
    ///
    /// API 명세:
    /// "참여한 채팅방에 새로운 채팅이 생길 경우, 채팅방 응답값의 updatedAt 값이 업데이트됩니다."
    /// -> 채팅방 목록 정렬 기준으로 사용
    let updatedAt: Date

    /// 상대방 정보
    let opponent: Opponent

    /// 마지막 채팅 메시지
    ///
    /// 채팅방 목록에서 미리보기로 표시
    /// nil일 수 있음 (아직 메시지가 없는 경우)
    let lastMessage: ChatMessage?

    /// 내가 마지막으로 읽은 시간 (로컬에서만 관리)
    ///
    /// 사용처:
    /// - 안 읽은 메시지 개수 계산
    /// - Badge 표시 여부 결정
    ///
    /// 서버에서 주지 않는 값! 클라이언트에서만 관리
    var lastReadAt: Date?

    // MARK: - Identifiable
    var id: String { roomId }

    // MARK: - Computed Properties
    /// 새 메시지 존재 여부 (빨간 점 표시용)
    ///
    /// 계산 방법:
    /// - lastReadAt이 nil이면 -> 한 번도 읽지 않았으므로 true
    /// - updatedAt > lastReadAt -> 내가 읽은 후 새 메시지 도착
    var hasUnreadMessage: Bool {
        guard let lastReadAt = lastReadAt else {
            return true // 한 번도 안 읽었으면 새 메시지로 간주
        }
        return updatedAt > lastReadAt
    }

    /// 마지막 메시지 미리보기 텍스트
    ///
    /// 채팅방 목록에 표시할 텍스트
    /// - 파일이 있으면: "사진 N장"
    /// - 텍스트만 있으면: 내용
    /// - 메시지 없으면: "대화를 시작해보세요"
    var lastMessagePreview: String {
        guard let lastMessage = lastMessage else {
            return "대화를 시작해보세요"
        }

        if lastMessage.hasFiles {
            return "사진 \(lastMessage.files.count)장"
        }

        return lastMessage.content ?? ""
    }
}

// MARK: - Nested Types
extension ChatRoom {

    /// 채팅 상대방 정보
    /// API participants 배열 중 나를 제외한 상대방
    /// 1:1 채팅이므로 항상 1명
    struct Opponent: Equatable, Hashable {
        let userId: String
        let nick: String
        let profileImage: String?

        /// 프로필 이미지가 있는지 여부
        var hasProfileImage: Bool {
            return profileImage != nil && !(profileImage?.isEmpty ?? true)
        }
    }
}

// MARK: - Helper Methods
extension ChatRoom {

    /// 마지막 읽은 시간 업데이트
    /// 채팅방을 열 때 호출
    ///
    /// - Returns: lastReadAt이 업데이트된 새 인스턴스
    func markAsRead() -> ChatRoom {
        return ChatRoom(
            roomId: roomId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            opponent: opponent,
            lastMessage: lastMessage,
            lastReadAt: Date() // 현재 시간으로 업데이트
        )
    }

    /// 마지막 메시지 업데이트
    /// 새 메시지가 도착했을 때 호출
    ///
    /// - Parameter message: 새로운 마지막 메시지
    /// - Returns: lastMessage가 업데이트된 새 인스턴스
    func with(lastMessage message: ChatMessage) -> ChatRoom {
        return ChatRoom(
            roomId: roomId,
            createdAt: createdAt,
            updatedAt: Date(), // 현재 시간으로 업데이트
            opponent: opponent,
            lastMessage: message,
            lastReadAt: lastReadAt
        )
    }
}
