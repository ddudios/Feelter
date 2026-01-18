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
    func updatePost(postId: String, requestDTO: UpdatePostRequestDTO) async throws -> PostDetail
    func deletePost(postId: String) async throws
    func likePost(postId: String, status: Bool) async throws -> Bool
    func uploadFiles(_ files: [UploadFile]) async throws -> [String]

    // Comments
    func createComment(postId: String, content: String) async throws -> Comment
    func updateComment(postId: String, commentId: String, content: String) async throws -> Comment
    func deleteComment(postId: String, commentId: String) async throws
}
