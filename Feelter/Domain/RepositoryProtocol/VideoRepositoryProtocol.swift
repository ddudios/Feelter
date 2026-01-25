//
//  VideoRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation

protocol VideoRepositoryProtocol {
    func fetchVideoList(
        next: String?,
        limit: Int?
    ) async throws -> (videos: [VideoSummary], nextCursor: String?)

    func fetchStream(videoId: String) async throws -> VideoStream
    func fetchSubtitle(url: String) async throws -> [SubtitleItem]
    func likeVideo(videoId: String, status: Bool) async throws -> Bool
}
