//
//  File.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct FilterListRequestDTO: Encodable {
    let next: String?
    let limit: String?
    let category: String?
    let orderBy: FilterSortType?
    
    enum CodingKeys: String, CodingKey {
        case next, limit, category
        case orderBy = "order_by"
    }
}

enum FilterSortType: String, Encodable {
    case latest
    case popularity
    case purchase
}
