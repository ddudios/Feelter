//
//  PostUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/21/26.
//

import Foundation

protocol PostUsecaseProtocol {
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
}

struct PostUsecase: PostUsecaseProtocol {

    private let repository: CommunityRepositoryProtocol

    init(repository: CommunityRepositoryProtocol) {
        self.repository = repository
    }

    func fetchGeolocationPosts(
        category: String?,
        longitude: Double?,
        latitude: Double?,
        maxDistance: Int?,
        limit: Int?,
        next: String?,
        orderBy: PostSortType
    ) async throws -> (posts: [PostSummary], nextCursor: String?) {
        try await repository.fetchGeolocationPosts(
            category: category,
            longitude: longitude,
            latitude: latitude,
            maxDistance: maxDistance,
            limit: limit,
            next: next,
            orderBy: orderBy
        )
    }

    func searchPosts(title: String?) async throws -> [PostSummary] {
        try await repository.searchPosts(title: title)
    }

    func fetchPostDetail(postId: String) async throws -> PostDetail {
        try await repository.fetchPostDetail(postId: postId)
    }
}
