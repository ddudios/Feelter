//
//  VideoUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation

protocol VideoUsecaseProtocol {
    func fetchVideoList(
        next: String?,
        limit: Int?
    ) async throws -> (videos: [VideoSummary], nextCursor: String?)

    func fetchStream(videoId: String) async throws -> VideoStream
    func likeVideo(videoId: String, status: Bool) async throws -> Bool
}

struct VideoUsecase: VideoUsecaseProtocol {

    private let repository: VideoRepositoryProtocol

    init(repository: VideoRepositoryProtocol) {
        self.repository = repository
    }

    func fetchVideoList(
        next: String?,
        limit: Int?
    ) async throws -> (videos: [VideoSummary], nextCursor: String?) {
        try await repository.fetchVideoList(next: next, limit: limit)
    }

    func fetchStream(videoId: String) async throws -> VideoStream {
        try await repository.fetchStream(videoId: videoId)
    }

    func likeVideo(videoId: String, status: Bool) async throws -> Bool {
        try await repository.likeVideo(videoId: videoId, status: status)
    }
}
