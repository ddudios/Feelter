//
//  FilterDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension FilterDTO {
    // DTO -> 목록형 Entity 변환
    func toSummaryDomain() -> FilterSummary {
        return FilterSummary(
            id: filterId,
            category: FilterCategory(rawValue: category) ?? .unknown,
            title: title,
            description: description,
            mainImageURL: files.first ?? "", // 썸네일은 첫 번째 이미지
            creator: creator.toDomain(),
            photographerName: creator.nick,
            likeCount: likeCount,
            isLiked: isLiked,
            createdAt: createdAt.toDate() ?? Date()
        )
    }
    
    // DTO -> 상세형 Entity 변환
    func toDetailDomain() -> FilterDetail {
        return FilterDetail(
            id: filterId,
            category: FilterCategory(rawValue: category) ?? .unknown,
            title: title,
            description: description,
            previewImages: files,
            price: price ?? 0, // 옵셔널 처리
            creator: creator.toDomain(),
            metadata: photoMetadata?.toDomain() ?? .empty,
            filterValues: filterValues?.toDomain(),
            comments: comments?.map { $0.toDomain() } ?? [],
            likeCount: likeCount,
            isLiked: isLiked,
            isDownloaded: isDownloaded ?? false,
            createdAt: createdAt.toDate() ?? Date()
        )
    }
}
