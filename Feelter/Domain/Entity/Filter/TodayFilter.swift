//
//  Filter.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation

struct TodayFilter: Hashable, Identifiable {
    let id: String
    let title: String
    let introduction: String
    let description: String
    let mainImageURL: String
    let createdAt: Date
    
    var formattedDate: String {
        return createdAt.formatted("yyyy.MM.dd")
    }
}
