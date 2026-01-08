//
//  UserSearchResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct UserSearchResponseDTO: Decodable {
    let data: [UserSearchItemDTO]
}

struct UserSearchItemDTO: Decodable {
    let userId: String
    let nick: String
    let name: String
    let introduction: String?
    let profileImage: String?
    let hashTags: [String]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nick, name, introduction, profileImage, hashTags
    }
}
