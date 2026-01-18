//
//  CommunityRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

protocol CommunityRepositoryProtocol {
    func fetchGeolocationPosts(
        category: String?,
        longitude: Double?,
        latitude: Double?,
        maxDistance: Int?,
        limit: Int?,
        next: String?,
        orderBy: PostSortType
    ) async throws -> (posts: [PostSummary], nextCursor: String?)
    func searchPosts(title: String?) async throws -> [PostSummary]
    func fetchPostDetail(postId: String) async throws -> PostDetail
    func createPost(requestDTO: CreatePostRequestDTO) async throws -> PostDetail
    func likePost(postId: String, status: Bool) async throws -> Bool
    func uploadFiles(_ files: [UploadFile]) async throws -> [String]
}
