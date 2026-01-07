//
//  FilterListResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct FilterListResponseDTO: Decodable {
    let data: [FilterDTO]
    let nextCursor: String?
    
    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}
