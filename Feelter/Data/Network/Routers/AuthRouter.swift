//
//  AuthRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//

import Foundation
import Alamofire

enum AuthRouter: BaseRouter {

    case refresh(accessToken: String, refreshToken: String)

    var method: HTTPMethod {
        return .get
    }

    var path: String {
        return "v1/auth/refresh"
    }

    var headers: HTTPHeaders {
        var headers = defaultHeaders

        switch self {
        case .refresh(let accessToken, let refreshToken):
            headers.add(name: "Authorization", value: accessToken)
            headers.add(name: "RefreshToken", value: refreshToken)
        }

        return headers
    }
}
