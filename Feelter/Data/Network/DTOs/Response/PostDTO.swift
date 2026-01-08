//
//  PostDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct PostDTO: Decodable {
    // [공통 - 목록/상세]
    let postId: String
    let category: String
    let title: String
    let content: String
    let geolocation: GeolocationDTO
    let creator: CreatorDTO
    let files: [String]
    let isLike: Bool
    let likeCount: Int
    let createdAt: String
    let updatedAt: String

    // [상세 전용 - 목록 조회시 nil]
    let comments: [CommentDTO]?

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case category, title, content, geolocation, creator, files
        case isLike = "is_like"
        case likeCount = "like_count"
        case createdAt, updatedAt, comments
    }
}
