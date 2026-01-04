//
//  SignUpRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//

import Foundation

struct JoinRequestDTO: Encodable {
    let email: String
    let password: String
    let nick: String
    let name: String
    let introduction: String
    let phoneNum: String
    let hashTags: [String]
    let deviceToken: String
}
