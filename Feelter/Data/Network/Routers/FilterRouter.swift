//
//  FilterRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation
import Alamofire

enum FilterRouter: BaseRouter {

    case filterList(body: FilterListRequestDTO)
    case filter(id: String)
    case todayFilter

    var method: HTTPMethod {
        switch self {
        case .filterList, .filter, .todayFilter:
            return .get
        }
    }

    var path: String {
        switch self {
        case .filterList: "/v1/filters"
        case let .filter(id): "/v1/filters/\(id)"
        case .todayFilter: "/v1/filters/today-filter"
        }
    }

    var queryParameters: Encodable? {
        switch self {
        case let .filterList(body): body
        case .filter, .todayFilter: nil
        }
    }
}
