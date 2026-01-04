//
//  BaseRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation
import Alamofire

protocol BaseRouter: URLRequestConvertible {
    var baseURL: URL { get }
    var method: HTTPMethod { get }
    var path: String { get }
    var headers: HTTPHeaders { get }
    var body: Encodable? { get }
}

extension BaseRouter {
    var baseURL: URL {
        return Config.baseURL
    }

    var defaultHeaders: HTTPHeaders {
        return [
            "Content-Type": "application/json",
            "SeSACKey": Config.apiKey
        ]
    }

    var headers: HTTPHeaders {
        return defaultHeaders
    }

    // 기본 body (없으면 nil)
    var body: Encodable? {
        return nil
    }

    // URLRequest 생성
    func asURLRequest() throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.method = method

        headers.forEach { header in
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        // Body 인코딩 (있는 경우만)
        if let body = body {
            request = try JSONParameterEncoder.default.encode(body, into: request)
        }

        return request
    }
}
