//
//  APIEventLogger.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//

import Foundation
import Alamofire

final class APIEventLogger: EventMonitor {
    let queue = DispatchQueue.main

    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        DispatchQueue.main.async {
            guard let url = request.request?.url?.absoluteString else { return }
            let statusCode = response.response?.statusCode ?? -1

            switch response.result {
            case .success:
                print("✅ [\(statusCode)] \(url)")
            case .failure(let error):
                print("❌ [\(statusCode)] \(url)")
                if let data = response.data, let errorMessage = String(data: data, encoding: .utf8) {
                    print("   Error: \(errorMessage)")
                } else {
                    print("   Error: \(error.localizedDescription)")
                }
            }
        }
    }
}
