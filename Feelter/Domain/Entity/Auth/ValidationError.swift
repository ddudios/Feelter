//
//  ValidationError.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import Foundation

enum ValidationError: Error {
    case invalidEmail
    case invalidPassword
    case emptyEmail
    case emptyPassword

    var description: String {
        switch self {
        case .invalidEmail:
            "유효하지 않은 이메일 형식입니다"
        case .invalidPassword:
            "비밀번호는 8자 이상이어야 합니다"
        case .emptyEmail:
            "이메일을 입력해주세요"
        case .emptyPassword:
            "비밀번호를 입력해주세요"
        }
    }
}
