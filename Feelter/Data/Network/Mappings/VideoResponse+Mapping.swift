//
//  VideoResponse+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation

extension VideoListResponseDTO {
    func toDomain() -> ([VideoSummary], String?) {
        let videos = data.map { $0.toSummaryDomain() }
        return (videos, nextCursor)
    }
}

extension VideoDTO {
    func toSummaryDomain() -> VideoSummary {
        return VideoSummary(
            id: videoId,
            fileName: fileName,
            title: title,
            description: description,
            duration: duration,
            thumbnailURL: thumbnailUrl,
            availableQualities: availableQualities,
            viewCount: viewCount,
            likeCount: likeCount,
            isLiked: isLiked,
            createdAt: createdAt.toDate() ?? Date()
        )
    }
}

extension StreamResponseDTO {
    func toDomain() -> VideoStream {
        return VideoStream(
            id: videoId,
            streamURL: streamUrl,
            qualities: qualities.map { $0.toDomain() },
            subtitles: subtitles.map { $0.toDomain() }
        )
    }
}

extension StreamQualityDTO {
    func toDomain() -> VideoQuality {
        return VideoQuality(
            quality: quality,
            url: url
        )
    }
}

extension StreamSubtitleDTO {
    func toDomain() -> VideoSubtitle {
        return VideoSubtitle(
            language: language,
            name: name,
            isDefault: isDefault,
            url: url
        )
    }
}
