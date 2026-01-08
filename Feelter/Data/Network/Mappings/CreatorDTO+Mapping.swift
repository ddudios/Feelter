//
//  CreatorDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension CreatorDTO {
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
