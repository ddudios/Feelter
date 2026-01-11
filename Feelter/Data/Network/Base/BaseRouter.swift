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
    var cachePolicy: URLRequest.CachePolicy { get }
    var timeoutInterval: TimeInterval { get }
    var body: Encodable? { get }
    var queryParameters: Encodable? { get }
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

    var cachePolicy: URLRequest.CachePolicy {
        return .useProtocolCachePolicy
    }

    // 기본 타임아웃 (30초)
    var timeoutInterval: TimeInterval {
        return 30
    }

    // 기본 queryParameters (없으면 nil)
    var queryParameters: Encodable? {
        return nil
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
        request.cachePolicy = cachePolicy
        request.timeoutInterval = timeoutInterval

        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.name) }
        
        if let queryParameters = queryParameters {
            let params = queryParameters
            request = try URLEncodedFormParameterEncoder(destination: .queryString)
                .encode(params, into: request)
        }
        
        if let body = body {
            request = try JSONParameterEncoder.default.encode(body, into: request)
        }
        
        return request
    }
}
