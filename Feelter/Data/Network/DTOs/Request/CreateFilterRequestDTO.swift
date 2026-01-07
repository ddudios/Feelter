//
//  CreateFilterRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct CreateFilterRequestDTO: Encodable {
    let category: String
    let title: String
    let price: Int
    let description: String
    let files: [String]
    let photoMetadata: PhotoMetadataDTO
    let filterValues: FilterValuesDTO
    
    enum CodingKeys: String, CodingKey {
        case category, title, price, description, files
        case photoMetadata = "photo_metadata"
        case filterValues = "filter_values"
    }
}
