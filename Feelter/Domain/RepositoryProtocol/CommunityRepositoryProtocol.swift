//
//  CommunityRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

protocol CommunityRepositoryProtocol {
    func likePost(postId: String, status: Bool) async throws -> Bool
}
