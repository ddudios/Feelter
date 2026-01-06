//
//  AuthHeaderModifier.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation
import Kingfisher

struct AuthHeaderModifier: ImageDownloadRequestModifier {
    
    func modified(for request: URLRequest) -> URLRequest? {
        var request = request
        
        // 1. 키체인이나 저장소에서 토큰 꺼내기
        // (주의: 여기서 비동기 await를 쓸 수 없으므로, 동기적으로 가져오거나 메모리에 캐싱된 값을 써야 함)
        if let token = KeychainManager.shared.read(account: "accessToken") {
            request.setValue(token, forHTTPHeaderField: "Authorization")
            request.setValue(Config.apiKey, forHTTPHeaderField: "SesacKey")
        }
        
        return request
    }
}
