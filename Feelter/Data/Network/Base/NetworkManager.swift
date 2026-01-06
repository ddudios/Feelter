//
//  NetworkManager.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//
import Foundation
import Alamofire

// 1. 프로토콜 정의 (의존성 관리)
protocol NetworkManagerProtocol {
    func request<T: Decodable, R: URLRequestConvertible>(_ endpoint: R, type: T.Type) async throws -> T
}

// 2. 구현체
final class NetworkManager: NetworkManagerProtocol {
    
    // APISession을 주입받음
    private let session: Session
    
    init(session: Session = APISession.shared.session) {
        self.session = session
    }
    
    // 3. R: Router(URLRequestConvertible 채택), T: 응답받을 DTO 타입
    func request<T: Decodable, R: URLRequestConvertible>(_ endpoint: R, type: T.Type) async throws -> T {
        
        // Alamofire의 async/await 기능 활용
        let dataTask = session.request(endpoint)
            .validate() // 200~299 상태코드 확인
            .serializingDecodable(T.self)  // Data -> Struct/Class(Decodable) -> success/failure CompletionHandler아닌 async/await를 통해 T객체 리턴
            
        let response = await dataTask.response
        
        switch response.result {
        case .success(let value):
            return value

        case .failure(let error):
            throw parseError(error, response: response.response, data: response.data)
        }
    }

    // 4. 에러 파싱 (Alamofire 에러 -> Custom Error)
    private func parseError(_ error: AFError, response: HTTPURLResponse?, data: Data?) -> NetworkError {
        if case .responseSerializationFailed(let reason) = error {
            print("디코딩 에러 발생: \(reason)")
            return .decodingError
        }

        guard let statusCode = response?.statusCode else {
            print("HTTP 응답 없음: \(error.localizedDescription)")
            return .unknownError(error.localizedDescription)
        }

        switch statusCode {
        case 400..<500:
            // 서버에서 보낸 에러 메시지 파싱 시도
            let serverMessage = parseErrorMessage(from: data)
            return .clientError(statusCode: statusCode, message: serverMessage)
        case 500...:
            return .serverError(statusCode: statusCode)
        default:
            return .unknownError("상태코드: \(statusCode), 내용: \(error.localizedDescription)")
        }
    }

    // 5. 서버 에러 메시지 파싱
    private func parseErrorMessage(from data: Data?) -> String? {
        guard let data = data else { return nil }

        do {
            let errorResponse = try JSONDecoder().decode(ErrorResponseDTO.self, from: data)
            return errorResponse.message
        } catch {
            return nil
        }
    }
}
