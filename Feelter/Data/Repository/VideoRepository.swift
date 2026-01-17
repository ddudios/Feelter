//
//  VideoRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation

final class VideoRepository: VideoRepositoryProtocol {

    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func fetchVideoList(
        next: String?,
        limit: Int?
    ) async throws -> (videos: [VideoSummary], nextCursor: String?) {
        let response = try await networkManager.request(
            VideoRouter.videoList(next: next, limit: limit),
            type: VideoListResponseDTO.self
        )

        return response.toDomain()
    }

    func fetchStream(videoId: String) async throws -> VideoStream {
        let response = try await networkManager.request(
            VideoRouter.stream(videoId: videoId),
            type: StreamResponseDTO.self
        )

        return response.toDomain()
    }

    func likeVideo(videoId: String, status: Bool) async throws -> Bool {
        let response = try await networkManager.request(
            VideoRouter.likeVideo(videoId: videoId, body: LikeRequestDTO(likeStatus: status)),
            type: LikeResponseDTO.self
        )

        return response.likeStatus
    }
}
