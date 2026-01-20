//
//  ProfileResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct ProfileResponseDTO: Decodable {
    let userId: String
    let email: String?
    let nick: String
    let name: String?
    let introduction: String?
    let profileImage: String?
    let phoneNum: String?
    let hashTags: [String]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email, nick, name, introduction, profileImage, phoneNum, hashTags
    }
}
