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

    // 설정 기반 파일 업로드 (새 버전)
    func uploadFiles(_ dataList: [Data], config: FileUploadConfig, endpoint: URLRequestConvertible) async throws -> [String]

    // 프로필 이미지 전용 업로드
    func uploadProfileImage(_ imageData: Data, endpoint: URLRequestConvertible) async throws -> String

    // 기존 메서드 (하위 호환성)
    @available(*, deprecated, message: "uploadFiles(_:config:endpoint:) 사용 권장")
    func uploadFiles(_ imageData: [Data], endpoint: URLRequestConvertible) async throws -> [String]
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
        if case .responseSerializationFailed = error {
            return .decodingError
        }

        guard let statusCode = response?.statusCode else {
            return .unknownError(error.localizedDescription)
        }

        switch statusCode {
        case 400..<500:
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

    // MARK: - 6. 파일 업로드

    // 6-1. 설정 기반 파일 업로드 (확장 가능한 버전)
    /// - Parameters:
    ///   - dataList: 업로드할 파일 데이터 배열
    ///   - config: 업로드 설정 (FileUploadConfig.profile, .chat 등)
    ///   - endpoint: API 엔드포인트
    /// - Returns: 업로드된 파일 경로 배열
    func uploadFiles(
        _ dataList: [Data],
        config: FileUploadConfig,
        endpoint: URLRequestConvertible
    ) async throws -> [String] {
        // 1. 유효성 검사
        try config.validate(dataList)

        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
                multipartFormData: { multipartFormData in
                    for (index, data) in dataList.enumerated() {
                        // 2. 확장자 추론 (첫 번째 허용 확장자 사용)
                        let fileExtension = config.allowedExtensions.first ?? "jpg"

                        // 3. MIME Type 자동 결정
                        let mimeType = FileUploadConfig.mimeType(for: fileExtension)

                        // 4. 파일명 생성
                        let timestamp = Date().timeIntervalSince1970
                        let fileName = "\(config.parameterName)_\(index)_\(timestamp).\(fileExtension)"

                        // 5. multipart 데이터 추가
                        multipartFormData.append(
                            data,
                            withName: config.parameterName,  // ✅ 설정에서 가져옴
                            fileName: fileName,
                            mimeType: mimeType  // ✅ 확장자에 맞게 자동 설정
                        )
                    }
                },
                with: endpoint
            )
            .validate()
            .responseDecodable(of: FileUploadResponseDTO.self) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value.files)
                case .failure(let error):
                    let networkError = self.parseError(error, response: response.response, data: response.data)
                    continuation.resume(throwing: networkError)
                }
            }
        }
    }

    // 6-2. 프로필 이미지 업로드 (단일 파일, 다른 응답 형식)
    /// - Parameters:
    ///   - imageData: 업로드할 이미지 데이터
    ///   - endpoint: API 엔드포인트
    /// - Returns: 업로드된 프로필 이미지 경로
    func uploadProfileImage(
        _ imageData: Data,
        endpoint: URLRequestConvertible
    ) async throws -> String {
        // 1. 유효성 검사
        try FileUploadConfig.profile.validate([imageData])

        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
                multipartFormData: { multipartFormData in
                    let config = FileUploadConfig.profile
                    let fileExtension = config.allowedExtensions.first ?? "jpg"
                    let mimeType = FileUploadConfig.mimeType(for: fileExtension)
                    let timestamp = Date().timeIntervalSince1970
                    let fileName = "profile_\(timestamp).\(fileExtension)"

                    multipartFormData.append(
                        imageData,
                        withName: "profile",  // ✅ 프로필은 "profile"
                        fileName: fileName,
                        mimeType: mimeType
                    )
                },
                with: endpoint
            )
            .validate()
            .responseDecodable(of: ProfileImageUploadResponseDTO.self) { response in  // ✅ 다른 DTO
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value.profileImage)  // ✅ .profileImage
                case .failure(let error):
                    let networkError = self.parseError(error, response: response.response, data: response.data)
                    continuation.resume(throwing: networkError)
                }
            }
        }
    }

    // 6-3. 기존 파일 업로드 메서드 (하위 호환성)
    /// - 내부적으로 새 메서드 호출
    @available(*, deprecated, message: "uploadFiles(_:config:endpoint:) 사용 권장")
    func uploadFiles(_ imageData: [Data], endpoint: URLRequestConvertible) async throws -> [String] {
        // 기본 설정으로 호출 (Filter/Post/Chat에서 사용)
        return try await uploadFiles(imageData, config: .post, endpoint: endpoint)
    }
}
