//
//  SearchPostItem.swift
//  Feelter
//
//  Created by Suji Jang on 1/21/26.
//

import Foundation

struct SearchPostItem: Hashable {
    let id: String
    let authorId: String
    let authorName: String
    let profileImagePath: String?
    let locationText: String?
    let latitude: Double
    let longitude: Double
    let imagePaths: [String]
    let isLiked: Bool
    let likeCount: Int
    let commentCount: Int
    let title: String
    let category: String
    let content: String
    let timeText: String
}
