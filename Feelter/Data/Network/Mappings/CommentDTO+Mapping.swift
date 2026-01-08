//
//  CommentDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension CommentDTO {
    func toDomain() -> Comment {
        return Comment(
            id: commentId,
            content: content,
            writer: creator.toDomain(),
            createdAt: createdAt.toDate() ?? Date(),
            replies: replies?.map { $0.toDomain() } ?? []
        )
    }
}
