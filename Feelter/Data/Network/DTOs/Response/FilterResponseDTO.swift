//
//  FilterResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation

struct FilterResponseDTO: Decodable {
    let filterId: String
    let title: String
    let introduction: String
    let description: String
    let files: [String]
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case filterId = "filter_id"
        case title
        case introduction
        case description
        case files
        case createdAt
        case updatedAt
    }
}

extension FilterResponseDTO {
    func toDomain() -> Filter {
        return Filter(
            id: filterId,
            title: title,
            introduction: introduction,
            description: description,
            files: files,
            createdAt: createdAt.toDate() ?? Date(),
            updatedAt: updatedAt.toDate() ?? Date()
        )
    }
}
