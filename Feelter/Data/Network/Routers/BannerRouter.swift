//
//  BannerRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation
import Alamofire

enum BannerRouter: BaseRouter {

    case fetchBanners

    var method: HTTPMethod {
        switch self {
        case .fetchBanners: return .get
        }
    }

    var path: String {
        switch self {
        case .fetchBanners: "v1/banners/main"
        }
    }
}
