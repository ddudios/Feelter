//
//  LikeRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct LikeRequestDTO: Encodable {
    let likeStatus: Bool
    
    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}
