//
//  TodayAuthorResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct TodayAuthorResponseDTO: Decodable {
    let author: AuthorInfoDTO
    let filters: [FilterDTO]
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
