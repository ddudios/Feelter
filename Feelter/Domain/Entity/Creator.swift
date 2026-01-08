//
//  Creator.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct Creator: Hashable, Identifiable {
    let id: String
    let nickname: String
    let name: String
    let introduction: String
    let profileImageURL: String?
    let hashTags: [String]
}
