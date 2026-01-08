//
//  TodayAuthorResponseDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension TodayAuthorResponseDTO {
    func toDomain() -> TodayAuthor {
        return TodayAuthor(
            author: author.toDomain(),
            filters: filters.map { $0.toSummaryDomain() }
        )
    }
}

extension AuthorInfoDTO {
    func toDomain() -> AuthorInfo {
        return AuthorInfo(
            id: userId,
            nickname: nick,
            name: name,
            introduction: introduction ?? "",
            description: description ?? "",
            profileImageURL: profileImage,
            hashTags: hashTags ?? []
        )
    }
}
