//
//  TodayAuthor.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct TodayAuthor: Hashable {
    let author: AuthorInfo
    let filters: [FilterSummary]
}

struct AuthorInfo: Hashable {
    let id: String
    let nickname: String
    let name: String
    let introduction: String
    let description: String
    let profileImageURL: String?
    let hashTags: [String]
}
