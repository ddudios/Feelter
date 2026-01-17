//
//  Video.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation

/// 목록 조회용 (가벼운 모델)
struct VideoSummary: Identifiable, Hashable {
    let id: String
    let fileName: String
    let title: String
    let description: String
    let duration: Double
    let thumbnailURL: String
    let availableQualities: [String]
    let viewCount: Int
    let likeCount: Int
    let isLiked: Bool
    let createdAt: Date
}

/// 스트리밍 정보
struct VideoStream {
    let id: String
    let streamURL: String
    let qualities: [VideoQuality]
    let subtitles: [VideoSubtitle]
}

struct VideoQuality: Hashable {
    let quality: String
    let url: String
}

struct VideoSubtitle: Hashable {
    let language: String
    let name: String
    let isDefault: Bool
    let url: String
}
