//
//  CommentDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct CommentDTO: Decodable {
    let commentId: String
    let content: String
    let createdAt: String
    let creator: CreatorDTO
    let replies: [CommentDTO]?
    
    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case content, createdAt, creator, replies
    }
}

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
