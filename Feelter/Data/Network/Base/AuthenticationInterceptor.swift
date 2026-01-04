//
//  AuthenticationInterceptor.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//

import Foundation
import Alamofire

final class AuthenticationInterceptor: RequestInterceptor {
    
    // 1. 요청을 보낼 때마다 헤더에 토큰 등을 끼워 넣는 역할 (Adapt)
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        // TODO: 여기서 Keychain에서 AccessToken을 꺼내 Header에 추가할 예정
        completion(.success(urlRequest))
    }
    
    // 2. 응답이 실패했을 때 재시도할지 결정하는 역할 (Retry)
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        // TODO: 401 에러 시 RefreshToken으로 재발급 요청
        completion(.doNotRetry)
    }
}
