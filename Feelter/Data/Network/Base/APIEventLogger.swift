//
//  APIEventLogger.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//

import Foundation
import Alamofire

final class APIEventLogger: EventMonitor {
    let queue = DispatchQueue(label: "FeelterNetworkLogger")
    
    // Request 시작
    func requestDidResume(_ request: Request) {
        print("\n==================== NETWORK REQUEST LOG ====================")
        debugPrint(request)
        print("===============================================================\n")
    }
    
    // Response 완료
    func request(_ request: Request, didParseResponse response: DataResponse<Data?, AFError>) {
        print("\n==================== NETWORK RESPONSE LOG ====================")
        
        switch response.result {
        case .success(let data):
            if let data = data {
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    print("DATA:\n\(prettyString)")
                } else {
                    // JSON이 아닌 경우 그냥 출력
                    print("DATA: \(String(data: data, encoding: .utf8) ?? "")")
                }
            }
        case .failure(let error):
            print("ERROR: \(request.request?.url?.absoluteString ?? "")")
            // URL은 객체이고, absoluteString은 그 객체가 품고 있는 실제 주소 텍스트(String)
            print("CODE: \(error.responseCode ?? -1)")
            print("DESCRIPTION: \(error.localizedDescription)")
        }
        
        print("===============================================================\n")
    }
}
