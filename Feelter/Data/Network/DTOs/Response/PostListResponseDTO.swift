//
//  PostListResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct PostListResponseDTO: Decodable {
    let data: [PostDTO]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}
