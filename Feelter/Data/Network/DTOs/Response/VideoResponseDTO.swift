//
//  VideoResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation

// 비디오 목록 조회 응답
struct VideoListResponseDTO: Decodable {
    let data: [VideoDTO]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

// 비디오 목록 아이템
struct VideoDTO: Decodable {
    let videoId: String
    let fileName: String
    let title: String
    let description: String
    let duration: Double
    let thumbnailUrl: String
    let availableQualities: [String]
    let viewCount: Int
    let likeCount: Int
    let isLiked: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case fileName = "file_name"
        case title, description, duration
        case thumbnailUrl = "thumbnail_url"
        case availableQualities = "available_qualities"
        case viewCount = "view_count"
        case likeCount = "like_count"
        case isLiked = "is_liked"
        case createdAt
    }
}

// 스트리밍 URL 조회 응답
struct StreamResponseDTO: Decodable {
    let videoId: String
    let streamUrl: String
    let qualities: [StreamQualityDTO]
    let subtitles: [StreamSubtitleDTO]

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case streamUrl = "stream_url"
        case qualities, subtitles
    }
}

struct StreamQualityDTO: Decodable {
    let quality: String
    let url: String
}

struct StreamSubtitleDTO: Decodable {
    let language: String
    let name: String
    let isDefault: Bool
    let url: String

    enum CodingKeys: String, CodingKey {
        case language, name, url
        case isDefault = "is_default"
    }
}
