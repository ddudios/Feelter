//
//  Comment.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct Comment: Identifiable {
    let id: String
    let content: String
    let writer: Creator
    let createdAt: Date
    let replies: [Comment]
}
