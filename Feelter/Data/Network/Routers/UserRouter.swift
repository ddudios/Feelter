//
//  UserRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//

import Foundation
import Alamofire

enum UserRouter: BaseRouter {

    case login(body: LoginRequestDTO)

    var method: HTTPMethod {
        switch self {
        case .login:
            return .post
        }
    }

    var path: String {
        switch self {
        case .login:
            return "v1/users/login"
        }
    }

    var body: Encodable? {
        switch self {
        case .login(let body):
            return body
        }
    }
}
