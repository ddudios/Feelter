//
//  User.swift
//  Feelter
//
//  Created by Suji Jang on 12/22/25.
//

import Foundation

struct User {
    let id: String
    let email: String
    let nickname: String
    let name: String?
    let introduction: String?
    let profileImageURL: String?
    let phoneNumber: String?
    let hashTags: [String]

    var displayName: String {
        nickname.isEmpty ? email : nickname
    }

    var hasProfileImage: Bool {
        profileImageURL != nil && !(profileImageURL?.isEmpty ?? true)
    }

    init(
        id: String,
        email: String,
        nickname: String,
        name: String? = nil,
        introduction: String? = nil,
        profileImageURL: String? = nil,
        phoneNumber: String? = nil,
        hashTags: [String] = []
    ) {
        self.id = id
        self.email = email
        self.nickname = nickname
        self.name = name
        self.introduction = introduction
        self.profileImageURL = profileImageURL
        self.phoneNumber = phoneNumber
        self.hashTags = hashTags
    }
}
