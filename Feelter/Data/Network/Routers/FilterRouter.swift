//
//  FilterRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation
import Alamofire

enum FilterRouter: BaseRouter {

    case todayFilter

    var method: HTTPMethod {
        switch self {
        case .todayFilter:
            return .get
        }
    }

    var path: String {
        switch self {
        case .todayFilter: "/v1/filters/today-filter"
        }
    }

    var body: Encodable? {
        switch self {
        case .todayFilter: nil
        }
    }
}
