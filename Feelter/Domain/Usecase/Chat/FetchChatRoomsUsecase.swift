//
//  FetchChatRoomsUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

/// 채팅방 목록 조회 UseCase
final class FetchChatRoomsUsecase {

    private let repository: ChatRepositoryProtocol

    init(repository: ChatRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws -> [ChatRoom] {
        return try await repository.fetchChatRooms()
    }
}
