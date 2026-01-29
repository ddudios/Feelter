//
//  SendMessageUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

final class SendMessageUsecase {

    // MARK: - Properties
    private let repository: ChatRepositoryProtocol

    // MARK: - Initialization
    init(repository: ChatRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute
    /// 메시지 전송 실행
    ///
    /// 비즈니스 로직:
    /// 1. 입력 검증 (빈 메시지 체크)
    /// 2. Repository를 통해 전송
    /// 3. 에러 처리
    ///
    /// Optimistic Update는 Repository에서 처리:
    /// - ViewModel에서는 신경 쓸 필요 없음
    /// - Repository가 알아서 즉시 CoreData에 저장
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    ///   - content: 메시지 내용
    ///   - files: 첨부 파일 URL 배열
    /// - Returns: 전송된 메시지
    /// - Throws: SendMessageError
    func execute(
        roomId: String,
        content: String,
        files: [String] = []
    ) async throws -> ChatMessage {

        // 1. 입력 검증
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 빈 메시지이고 파일도 없으면 에러
        guard !trimmedContent.isEmpty || !files.isEmpty else {
            throw SendMessageError.emptyMessage
        }

        // 메시지 길이 제한 (예: 5000자)
        guard trimmedContent.count <= 5000 else {
            throw SendMessageError.messageTooLong
        }

        // 2. Repository 호출
        do {
            // 이미지만 보낼 때는 content를 nil로 전달
            let contentToSend: String? = trimmedContent.isEmpty && !files.isEmpty ? nil : trimmedContent

            let message = try await repository.sendMessage(
                roomId: roomId,
                content: contentToSend,
                files: files
            )

            return message

        } catch {
            // 3. 에러 변환
            // NetworkError -> SendMessageError로 변환
            throw SendMessageError.from(error)
        }
    }
}

// MARK: - Error
extension SendMessageUsecase {
    
    enum SendMessageError: LocalizedError {

        /// 빈 메시지 (텍스트도 없고 파일도 없음)
        case emptyMessage

        /// 메시지가 너무 김 (5000자 초과)
        case messageTooLong

        /// 네트워크 에러
        case networkError

        /// 서버 에러
        case serverError

        /// 알 수 없는 에러
        case unknown

        // MARK: - LocalizedError
        var errorDescription: String? {
            switch self {
            case .emptyMessage:
                return "메시지 내용을 입력해주세요."
            case .messageTooLong:
                return "메시지가 너무 깁니다. (최대 5000자)"
            case .networkError:
                return "네트워크 연결을 확인해주세요."
            case .serverError:
                return "서버 오류가 발생했습니다."
            case .unknown:
                return "알 수 없는 오류가 발생했습니다."
            }
        }

        // MARK: - Factory

        /// Error를 SendMessageError로 변환
        ///
        /// - Parameter error: 원본 에러
        /// - Returns: SendMessageError
        static func from(_ error: Error) -> SendMessageError {
            // SendMessageError는 그대로 반환
            if let sendError = error as? SendMessageError {
                return sendError
            }

            // NetworkError 확인
            if let networkError = error as? NetworkError {
                switch networkError {
                case .networkConnectionError:
                    return .networkError
                case .serverError:
                    return .serverError
                case .clientError, .decodingError, .invalidURL, .unknownError:
                    return .unknown
                }
            }

            // URLError 확인 (비행기 모드, 인터넷 연결 끊김 등)
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                    return .networkError
                case .timedOut:
                    return .networkError
                default:
                    return .networkError
                }
            }

            // NSError 확인 (URLError가 NSError로 래핑된 경우)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                return .networkError
            }

            // 기타 에러
            return .unknown
        }
    }
}
