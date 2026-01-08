//
//  ProfileUpdateRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct ProfileUpdateRequestDTO: Encodable {
    let nick: String?
    let name: String?
    let introduction: String?
    let phoneNum: String?
    let profileImage: String?
    let hashTags: [String]?
}
