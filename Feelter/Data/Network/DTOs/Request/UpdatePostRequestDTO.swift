//
//  UpdatePostRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct UpdatePostRequestDTO: Encodable {
    let category: String?
    let title: String?
    let content: String?
    let latitude: Double?
    let longitude: Double?
    let files: [String]?
}
