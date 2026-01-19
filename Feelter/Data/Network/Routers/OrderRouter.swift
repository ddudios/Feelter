//
//  OrderRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import Foundation
import Alamofire

enum OrderRouter: BaseRouter {

    case fetchOrders

    var method: HTTPMethod {
        switch self {
        case .fetchOrders:
            return .get
        }
    }

    var cachePolicy: URLRequest.CachePolicy {
        return .reloadIgnoringLocalCacheData
    }

    var path: String {
        switch self {
        case .fetchOrders:
            return "/v1/orders"
        }
    }

    var parameters: Parameters? {
        return nil
    }

    var encoding: ParameterEncoding {
        return URLEncoding.default
    }

    var headers: HTTPHeaders? {
        return nil
    }
}
