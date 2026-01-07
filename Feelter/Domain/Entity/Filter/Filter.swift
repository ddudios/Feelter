//
//  Filter.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

/// 목록 조회용 (가벼운 모델)
struct FilterSummary: Identifiable {
    let id: String
    let category: FilterCategory
    let title: String
    let description: String
    let mainImageURL: String // files의 첫 번째 이미지
    let creator: Creator
    let photographerName: String
    let likeCount: Int
    let isLiked: Bool
    let createdAt: Date
}

/// 상세 조회용 (상세 모델)
struct FilterDetail: Identifiable {
    let id: String
    let category: FilterCategory
    let title: String
    let description: String
    let previewImages: [String] // files 전체
    let price: Int
    let creator: Creator
    
    let metadata: PhotoMetadata
    let filterValues: FilterValues?
    let comments: [Comment]
    
    let likeCount: Int
    let isLiked: Bool
    let isDownloaded: Bool
    let createdAt: Date
}

enum FilterCategory: String, CaseIterable {
    case food = "푸드"
    case portrait = "인물"
    case landscape = "풍경"
    case night = "야경"
    case star = "별"
    case unknown = "기타"
}
