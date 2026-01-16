//
//  CreatorDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct CreatorDTO: Decodable {
    let userId: String
    let nick: String
    let name: String?  // Apple 로그인 시 없을 수 있음
    let introduction: String?
    let profileImage: String?
    let hashTags: [String]? // 빈 배열일 수도, nil일 수도 있어서 확인 필요 (보통 배열은 빈배열로 옴)

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nick, name, introduction, profileImage, hashTags
    }
}
