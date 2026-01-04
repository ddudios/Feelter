//
//  LoginRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation

struct LoginRequestDTO: Encodable {
    let email: String
    let password: String
    let deviceToken: String?
}
