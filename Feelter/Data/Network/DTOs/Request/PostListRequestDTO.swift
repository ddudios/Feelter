//
//  PostListRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct PostListRequestDTO: Encodable {
    let category: String?
    let longitude: String?
    let latitude: String?
    let maxDistance: String?
    let limit: Int?
    let next: String?
    let orderBy: PostSortType?

    enum CodingKeys: String, CodingKey {
        case category, longitude, latitude, maxDistance, limit, next
        case orderBy = "order_by"
    }
}

enum PostSortType: String, Encodable {
    case createdAt
    case likes
}
