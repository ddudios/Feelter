//
//  APISession.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//

import Foundation
import Alamofire

final class APISession {
    
    // 싱글톤으로 사용하여 앱 전역에서 하나의 세션만 유지 (리소스 절약)
    static let shared = APISession()
    
    let session: Session
    
    private init() {
        // 1. 통신 설정
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 요청 300초 대기 (동영상 업로드 고려)
        configuration.timeoutIntervalForResource = 600 // 리소스 다운로드 대기 (큰 동영상 처리 10분)
        configuration.requestCachePolicy = .returnCacheDataElseLoad

        // 2. Session 생성 (Interceptor, EventMonitor 주입)
        self.session = Session(
            configuration: configuration,
            interceptor: AuthenticationInterceptor(), // 토큰 관리자
            eventMonitors: [APIEventLogger()]         // 로그 출력자
        )
    }
}
