//
//  CommunityRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

final class CommunityRepository: CommunityRepositoryProtocol {
    
    private let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }
    
    func likePost(postId: String, status: Bool) async throws -> Bool {
        // Router 호출
        let router = CommunityRouter.likePost(postId: postId, status: status)
        
        // DTO 받기
        let response = try await networkManager.request(router, type: LikeResponseDTO.self)
        
        // DTO -> Domain(Bool) 변환
        return response.likeStatus
    }
}
