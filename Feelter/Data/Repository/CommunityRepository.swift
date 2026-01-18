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

    func fetchGeolocationPosts(
        category: String?,
        longitude: Double?,
        latitude: Double?,
        maxDistance: Int?,
        limit: Int?,
        next: String?,
        orderBy: PostSortType
    ) async throws -> (posts: [PostSummary], nextCursor: String?) {
        let requestDTO = PostListRequestDTO(
            category: category,
            longitude: longitude.map { String(format: "%.6f", $0) },
            latitude: latitude.map { String(format: "%.6f", $0) },
            maxDistance: maxDistance.map { String($0) },
            limit: limit,
            next: next,
            orderBy: orderBy
        )

        let response = try await networkManager.request(
            PostRouter.geolocationPosts(query: requestDTO),
            type: PostListResponseDTO.self
        )

        return response.toDomain()
    }

    func searchPosts(title: String?) async throws -> [PostSummary] {
        let requestDTO = PostSearchRequestDTO(title: title)

        let response = try await networkManager.request(
            PostRouter.searchPosts(query: requestDTO),
            type: PostSearchResponseDTO.self
        )

        return response.toDomain()
    }

    func fetchPostDetail(postId: String) async throws -> PostDetail {
        let response = try await networkManager.request(
            PostRouter.post(id: postId),
            type: PostDTO.self
        )

        return response.toDetailDomain()
    }

    func createPost(requestDTO: CreatePostRequestDTO) async throws -> PostDetail {
        let response = try await networkManager.request(
            PostRouter.createPost(body: requestDTO),
            type: PostDTO.self
        )

        return response.toDetailDomain()
    }

    func likePost(postId: String, status: Bool) async throws -> Bool {
        // Router 호출
        let router = PostRouter.likePost(
            id: postId,
            body: LikeRequestDTO(likeStatus: status)
        )

        // DTO 받기
        let response = try await networkManager.request(router, type: LikeResponseDTO.self)

        // DTO -> Domain(Bool) 변환
        return response.likeStatus
    }

    func uploadFiles(_ files: [UploadFile]) async throws -> [String] {
        let dataList = files.map { $0.data }
        let fileExtensions = files.map { $0.normalizedFileExtension }

        return try await networkManager.uploadFiles(
            dataList,
            fileExtensions: fileExtensions,
            config: .post,
            endpoint: PostRouter.uploadFiles(imageData: dataList)
        )
    }
}
