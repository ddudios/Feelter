//
//  KakaoLoginRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

struct KakaoLoginRequestDTO: Encodable {
    let oauthToken: String
    let deviceToken: String
}
