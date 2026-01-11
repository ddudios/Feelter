//
//  CreateChatRoomUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

/// 채팅방 생성(조회) UseCase
final class CreateChatRoomUsecase {

    private let repository: ChatRepositoryProtocol

    init(repository: ChatRepositoryProtocol) {
        self.repository = repository
    }

    func execute(opponentId: String) async throws -> ChatRoom {
        guard !opponentId.isEmpty else {
            throw CreateChatRoomError.invalidOpponentId
        }
        return try await repository.createOrFetchChatRoom(opponentId: opponentId)
    }

    enum CreateChatRoomError: LocalizedError {
        case invalidOpponentId

        var errorDescription: String? {
            return "유효하지 않은 사용자입니다."
        }
    }
}
