//
//  FilterDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct FilterDTO: Decodable {
    // [공통 - 목록/상세]
    let filterId: String
    let category: String
    let title: String
    let description: String
    let files: [String]
    let creator: CreatorDTO
    let isLiked: Bool
    let likeCount: Int
    let buyerCount: Int
    let createdAt: String
    let updatedAt: String
    
    // [상세 전용 - 목록 조회시 nil]
    let price: Int?
    let photoMetadata: PhotoMetadataDTO?
    let filterValues: FilterValuesDTO?
    let isDownloaded: Bool?
    let comments: [CommentDTO]?
    
    enum CodingKeys: String, CodingKey {
        case filterId = "filter_id"
        case category, title, description, files, creator
        case isLiked = "is_liked"
        case likeCount = "like_count"
        case buyerCount = "buyer_count"
        case createdAt, updatedAt
        
        // 상세 필드
        case price, photoMetadata, filterValues, comments
        case isDownloaded = "is_downloaded"
    }
}

extension FilterDTO {
    // DTO -> 목록형 Entity 변환
        func toSummaryDomain() -> FilterSummary {
            return FilterSummary(
                id: filterId,
                category: FilterCategory(rawValue: category) ?? .unknown,
                title: title,
                mainImageURL: files.first ?? "", // 썸네일은 첫 번째 이미지
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
