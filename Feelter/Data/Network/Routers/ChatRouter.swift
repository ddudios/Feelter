//
//  ChatRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation
import Alamofire

enum ChatRouter: BaseRouter {

    case createChatRoom(opponentId: String)  // 채팅방 생성 또는 조회
    case fetchChatRooms  // 채팅방 목록 조회
    case sendMessage(roomId: String, content: String?, files: [String]?)
    case fetchChatHistory(roomId: String, next: String?)
    case uploadFiles(roomId: String, imageData: [Data])  // 파일 업로드

    var method: HTTPMethod {
        switch self {
        case .createChatRoom, .sendMessage, .uploadFiles:
            return .post
        case .fetchChatRooms, .fetchChatHistory:
            return .get
        }
    }

    var path: String {
        switch self {
        case .createChatRoom:
            return "/v1/chats"

        case .fetchChatRooms:
            return "/v1/chats"

        case .sendMessage(let roomId, _, _):
            return "/v1/chats/\(roomId)"

        case .fetchChatHistory(let roomId, _):
            return "/v1/chats/\(roomId)"

        case .uploadFiles(let roomId, _):
            return "/v1/chats/\(roomId)/files"
        }
    }

    var body: Encodable? {
        switch self {
        case .createChatRoom(let opponentId):
            return CreateChatRoomRequestDTO(opponentId: opponentId)

        case .sendMessage(_, let content, let files):
            return SendMessageRequestDTO(content: content, files: files)

        case .fetchChatRooms, .fetchChatHistory, .uploadFiles:
            return nil
        }
    }

    var queryParameters: Encodable? {
        switch self {
        case .fetchChatHistory(_, let next):
            // next가 nil이면 쿼리 없음
            if let next = next {
                return FetchChatHistoryQuery(next: next)
            }
            return nil

        case .createChatRoom, .fetchChatRooms, .sendMessage, .uploadFiles:
            return nil
        }
    }
}

extension ChatRouter {

    /// 채팅 내역 조회 Query 파라미터
    private struct FetchChatHistoryQuery: Encodable {
        let next: String
    }
}
