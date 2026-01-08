//
//  PostListResponseDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension PostListResponseDTO {
    func toDomain() -> ([PostSummary], String?) {
        let posts = data.map { $0.toSummaryDomain() }
        return (posts, nextCursor)
    }
}
