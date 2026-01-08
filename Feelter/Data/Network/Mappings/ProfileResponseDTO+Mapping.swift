//
//  ProfileResponseDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension ProfileResponseDTO {
    func toDomain() -> User {
        return User(
            id: userId,
            email: email ?? "",
            nickname: nick,
            name: name,
            introduction: introduction,
            profileImageURL: profileImage,
            phoneNumber: phoneNum,
            hashTags: hashTags ?? []
        )
    }
}
