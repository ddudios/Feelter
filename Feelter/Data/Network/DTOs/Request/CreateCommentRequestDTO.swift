//
//  CreateCommentRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct CreateCommentRequestDTO: Encodable {
    let parentCommentId: String?
    let content: String

    enum CodingKeys: String, CodingKey {
        case parentCommentId = "parent_comment_id"
        case content
    }
}
