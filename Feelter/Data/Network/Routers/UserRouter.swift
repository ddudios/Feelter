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
    case logout

    var method: HTTPMethod {
        switch self {
        case .login, .logout:
            return .post
        }
    }

    var path: String {
        switch self {
        case .login: "v1/users/login"
        case .logout: "v1/users/logout"
        }
    }

    var body: Encodable? {
        switch self {
        case .login(let body): body
        case .logout: nil
        }
    }
}
