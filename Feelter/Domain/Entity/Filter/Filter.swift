//
//  Filter.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation

struct Filter: Hashable {
    let id: String
    let title: String
    let introduction: String
    let description: String
    let files: [String]
    let createdAt: Date
    let updatedAt: Date

    var formattedDate: String {
        return createdAt.formatted("yyyy.MM.dd")
    }
}
