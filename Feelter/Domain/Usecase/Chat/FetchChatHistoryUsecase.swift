//
//  FetchChatHistoryUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

/// 채팅 내역 조회 UseCase
final class FetchChatHistoryUsecase {

    private let repository: ChatRepositoryProtocol

    init(repository: ChatRepositoryProtocol) {
        self.repository = repository
    }

    func execute(roomId: String) async throws -> [ChatMessage] {
        guard !roomId.isEmpty else {
            throw FetchChatHistoryError.invalidRoomId
        }
        return try await repository.fetchChatHistory(roomId: roomId)
    }

    enum FetchChatHistoryError: LocalizedError {
        case invalidRoomId

        var errorDescription: String? {
            return "유효하지 않은 채팅방입니다."
        }
    }
}
