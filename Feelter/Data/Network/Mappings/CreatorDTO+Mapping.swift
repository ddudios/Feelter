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
            name: name ?? nick,  // Apple 로그인 시 name이 없으면 nickname 사용
            introduction: introduction ?? "",
            profileImageURL: profileImage,
            hashTags: hashTags ?? []
        )
    }
}
