//
//  TodayAuthorResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct TodayAuthorResponseDTO: Decodable {
    let author: AuthorInfoDTO
    let filters: [TodayAuthorFilterDTO]
}

struct AuthorInfoDTO: Decodable {
    let userId: String
    let nick: String
    let name: String
    let introduction: String?
    let description: String?
    let profileImage: String?
    let hashTags: [String]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nick, name, introduction, description, profileImage, hashTags
    }
}

struct TodayAuthorFilterDTO: Decodable {
    let filterId: String
    let category: String?
    let title: String
    let description: String
    let files: [String]
    let creator: CreatorDTO
    let isLiked: Bool?
    let likeCount: Int?
    let buyerCount: Int?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case filterId = "filter_id"
        case id
        case category, title, description, files, creator
        case isLiked = "is_liked"
        case likeCount = "like_count"
        case buyerCount = "buyer_count"
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let filterIdValue = try? container.decode(String.self, forKey: .filterId) {
            filterId = filterIdValue
        } else if let idValue = try? container.decode(String.self, forKey: .id) {
            filterId = idValue
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.filterId,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "filter_id 또는 id 필드를 찾을 수 없습니다"
                )
            )
        }

        category = try? container.decode(String.self, forKey: .category)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        files = try container.decode([String].self, forKey: .files)
        creator = try container.decode(CreatorDTO.self, forKey: .creator)
        isLiked = try? container.decode(Bool.self, forKey: .isLiked)
        likeCount = try? container.decode(Int.self, forKey: .likeCount)
        buyerCount = try? container.decode(Int.self, forKey: .buyerCount)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
}
