//
//  AppleLoginRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct AppleLoginRequestDTO: Encodable {
    let idToken: String
    let deviceToken: String
}
