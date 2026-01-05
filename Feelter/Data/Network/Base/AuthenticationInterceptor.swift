//
//  AuthenticationInterceptor.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//

import Foundation
import Alamofire

final class AuthenticationInterceptor: RequestInterceptor {

    private var isRefreshing = false
    private var requestsToRetry: [(RetryResult) -> Void] = []

    // 1. 요청을 보낼 때마다 헤더에 토큰 등을 끼워 넣는 역할 (Adapt)
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest

        // Refresh 요청은 AuthRouter에서 직접 헤더를 설정하므로 건너뜀
        if urlRequest.url?.absoluteString.contains("auth/refresh") == true {
            completion(.success(urlRequest))
            return
        }

        // Keychain에서 AccessToken 가져오기
        if let accessToken = KeychainManager.shared.read(account: "accessToken") {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        completion(.success(urlRequest))
    }

    // 2. 응답이 실패했을 때 재시도할지 결정하는 역할 (Retry)
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let response = request.task?.response as? HTTPURLResponse,
              response.statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        // Refresh 요청 자체가 실패한 경우 로그아웃 처리
        if request.request?.url?.absoluteString.contains("auth/refresh") == true {
            NotificationCenter.default.post(name: .unauthorizedError, object: nil)
            completion(.doNotRetry)
            return
        }

        // 이미 토큰 갱신 중이면 큐에 추가
        requestsToRetry.append(completion)

        // 첫 번째 요청만 갱신 시작
        guard !isRefreshing else { return }

        isRefreshing = true

        // 키체인에서 토큰 가져오기
        guard let accessToken = KeychainManager.shared.read(account: "accessToken"),
              let refreshToken = KeychainManager.shared.read(account: "refreshToken") else {
            NotificationCenter.default.post(name: .unauthorizedError, object: nil)
            isRefreshing = false
            requestsToRetry.forEach { $0(.doNotRetry) }
            requestsToRetry.removeAll()
            return
        }

        // RefreshToken으로 새 토큰 발급
        Task {
            do {
                let repository = AuthRepository()
                let newToken = try await repository.refreshToken(
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )

                // 새 토큰 저장
                KeychainManager.shared.save(token: newToken.accessToken, account: "accessToken")
                KeychainManager.shared.save(token: newToken.refreshToken, account: "refreshToken")

                // 대기 중인 모든 요청 재시도
                await MainActor.run {
                    self.isRefreshing = false
                    self.requestsToRetry.forEach { $0(.retry) }
                    self.requestsToRetry.removeAll()
                }
            } catch {
                // Refresh 실패 시 로그아웃
                await MainActor.run {
                    NotificationCenter.default.post(name: .unauthorizedError, object: nil)
                    self.isRefreshing = false
                    self.requestsToRetry.forEach { $0(.doNotRetry) }
                    self.requestsToRetry.removeAll()
                }
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let unauthorizedError = Notification.Name("unauthorizedError")
}
