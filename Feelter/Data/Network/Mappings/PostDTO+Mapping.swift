//
//  PostDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension PostDTO {
    // DTO -> 목록형 Entity 변환
    func toSummaryDomain() -> PostSummary {
        return PostSummary(
            id: postId,
            category: category,
            title: title,
            content: content,
            geolocation: geolocation.toDomain(),
            creator: creator.toDomain(),
            files: files,
            isLiked: isLike,
            likeCount: likeCount,
            createdAt: createdAt.toDate() ?? Date(),
            updatedAt: updatedAt.toDate() ?? Date()
        )
    }

    // DTO -> 상세형 Entity 변환
    func toDetailDomain() -> PostDetail {
        return PostDetail(
            id: postId,
            category: category,
            title: title,
            content: content,
            geolocation: geolocation.toDomain(),
            creator: creator.toDomain(),
            files: files,
            isLiked: isLike,
            likeCount: likeCount,
            comments: comments?.map { $0.toDomain() } ?? [],
            createdAt: createdAt.toDate() ?? Date(),
            updatedAt: updatedAt.toDate() ?? Date()
        )
    }
}
