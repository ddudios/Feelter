//
//  User.swift
//  Feelter
//
//  Created by Suji Jang on 12/22/25.
//

import Foundation

struct User: Decodable {
    let id: String
    let email: String
    let nick: String
    let name: String
    let introduction: String
    let profileImage: String
    let phoneNum: String
    let hashTags: [String]
    
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case email
        case nick
        case name
        case introduction
        case profileImage
        case phoneNum
        case hashTags
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.email = try container.decode(String.self, forKey: .email)
        self.nick = try container.decode(String.self, forKey: .nick)
        self.name = try container.decode(String.self, forKey: .name)
        self.introduction = try container.decode(String.self, forKey: .introduction)
        self.profileImage = try container.decode(String.self, forKey: .profileImage)
        self.phoneNum = try container.decode(String.self, forKey: .phoneNum)
        self.hashTags = try container.decode([String].self, forKey: .hashTags)
    }
}
