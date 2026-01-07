//
//  LikePostUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

protocol LikePostUsecaseProtocol {
    /// 게시글 좋아요/취소 실행
    func execute(postId: String, isLiked: Bool) async throws -> Bool
}

final class LikePostUsecase: LikePostUsecaseProtocol {
    
    private let repository: CommunityRepositoryProtocol
    
    init(repository: CommunityRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(postId: String, isLiked: Bool) async throws -> Bool {
        // 현재 상태(isLiked)를 받아서 -> 반대 값(!isLiked)으로 요청을 보냄
        let nextStatus = !isLiked
        return try await repository.likePost(postId: postId, status: nextStatus)
    }
}
