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
    let isLiked: Bool?        // 결제 검증 응답에는 없을 수 있음
    let likeCount: Int?       // 결제 검증 응답에는 없을 수 있음
    let buyerCount: Int?      // 결제 검증 응답에는 없을 수 있음
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
        case id  // 결제 검증 API에서 사용
        case category, title, description, files, creator
        case isLiked = "is_liked"
        case likeCount = "like_count"
        case buyerCount = "buyer_count"
        case createdAt, updatedAt

        // 상세 필드
        case price, photoMetadata, filterValues, comments
        case isDownloaded = "is_downloaded"
    }

    // 커스텀 디코딩: "filter_id" 또는 "id" 둘 다 지원
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // filterId: "filter_id" 또는 "id"를 시도
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

        // 나머지 필드들은 기본 디코딩
        category = try container.decode(String.self, forKey: .category)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        files = try container.decode([String].self, forKey: .files)
        creator = try container.decode(CreatorDTO.self, forKey: .creator)
        isLiked = try? container.decode(Bool.self, forKey: .isLiked)
        likeCount = try? container.decode(Int.self, forKey: .likeCount)
        buyerCount = try? container.decode(Int.self, forKey: .buyerCount)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)

        price = try? container.decode(Int.self, forKey: .price)
        photoMetadata = try? container.decode(PhotoMetadataDTO.self, forKey: .photoMetadata)
        filterValues = try? container.decode(FilterValuesDTO.self, forKey: .filterValues)
        isDownloaded = try? container.decode(Bool.self, forKey: .isDownloaded)
        comments = try? container.decode([CommentDTO].self, forKey: .comments)
    }
}
