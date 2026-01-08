//
//  Post.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

/// 목록 조회용 (가벼운 모델)
struct PostSummary: Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let content: String
    let geolocation: Geolocation
    let creator: Creator
    let files: [String]
    let isLiked: Bool
    let likeCount: Int
    let createdAt: Date
    let updatedAt: Date
}

/// 상세 조회용 (상세 모델)
struct PostDetail: Identifiable {
    let id: String
    let category: String
    let title: String
    let content: String
    let geolocation: Geolocation
    let creator: Creator
    let files: [String]
    let isLiked: Bool
    let likeCount: Int
    let comments: [Comment]
    let createdAt: Date
    let updatedAt: Date
}
