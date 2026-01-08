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
