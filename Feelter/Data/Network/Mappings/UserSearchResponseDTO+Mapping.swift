//
//  UserSearchResponseDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension UserSearchResponseDTO {
    func toDomain() -> [Creator] {
        return data.map { $0.toDomain() }
    }
}

extension UserSearchItemDTO {
    func toDomain() -> Creator {
        return Creator(
            id: userId,
            nickname: nick,
            name: name,
            introduction: introduction ?? "",
            profileImageURL: profileImage,
            hashTags: hashTags ?? []
        )
    }
}
