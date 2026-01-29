//
//  PaymentErrorMapper.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

struct PaymentErrorMapper {

    static func mapToUserFriendlyMessage(_ error: NetworkError) -> String {
        switch error {
        case .clientError(let statusCode, let message):
            return mapClientError(statusCode: statusCode, message: message)

        case .serverError(let statusCode):
            return mapServerError(statusCode: statusCode)

        case .decodingError:
            return "결제 정보를 처리하는 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요."

        case .unknownError(let description):
            return mapUnknownError(description: description)
        case .invalidURL:
            return "요청 주소가 올바르지 않습니다.\n잠시 후 다시 시도해주세요."
        case .networkConnectionError:
            return "네트워크 연결을 확인해 주세요"
        }
    }

    static func mapToUserFriendlyMessage(_ error: Error) -> String {
        if let networkError = error as? NetworkError {
            return mapToUserFriendlyMessage(networkError)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return mapNSURLError(nsError)
        }

        return "결제 처리 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요."
    }

    private static func mapClientError(statusCode: Int, message: String?) -> String {
        switch statusCode {
        case 400:
            // 서버 메시지가 있으면 우선 사용
            if let message = message, !message.isEmpty {
                return message
            }
            return "잘못된 요청입니다.\n다시 시도해주세요."

        case 401:
            return "로그인이 필요합니다.\n다시 로그인해주세요."

        case 403:
            return "접근 권한이 없습니다."

        case 404:
            return "요청하신 정보를 찾을 수 없습니다."

        case 409:
            if let message = message, !message.isEmpty {
                return message
            }
            return "이미 처리된 요청입니다."

        case 422:
            if let message = message, !message.isEmpty {
                return message
            }
            return "입력 정보를 확인해주세요."

        default:
            if let message = message, !message.isEmpty {
                return message
            }
            return "요청 처리 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요."
        }
    }

    private static func mapServerError(statusCode: Int) -> String {
        switch statusCode {
        case 500:
            return "서버 오류가 발생했습니다.\n잠시 후 다시 시도해주세요."

        case 502, 503:
            return "서버가 일시적으로 응답하지 않습니다.\n잠시 후 다시 시도해주세요."

        case 504:
            return "서버 응답 시간이 초과되었습니다.\n잠시 후 다시 시도해주세요."

        default:
            return "서버 오류가 발생했습니다.\n잠시 후 다시 시도해주세요."
        }
    }

    private static func mapNSURLError(_ error: NSError) -> String {
        switch error.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost:
            return "인터넷 연결을 확인해주세요."

        case NSURLErrorTimedOut:
            return "네트워크 연결이 불안정합니다.\n잠시 후 다시 시도해주세요."

        case NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost:
            return "서버에 연결할 수 없습니다.\n잠시 후 다시 시도해주세요."

        case NSURLErrorBadServerResponse:
            return "서버 응답이 올바르지 않습니다.\n잠시 후 다시 시도해주세요."

        case NSURLErrorCancelled:
            return "요청이 취소되었습니다."

        default:
            return "네트워크 오류가 발생했습니다.\n인터넷 연결을 확인해주세요."
        }
    }
    
    private static func mapUnknownError(description: String) -> String {
        if description.lowercased().contains("timeout") ||
           description.lowercased().contains("timed out") {
            return "네트워크 연결이 불안정합니다.\n잠시 후 다시 시도해주세요."
        }

        if description.lowercased().contains("network") ||
           description.lowercased().contains("connection") {
            return "인터넷 연결을 확인해주세요."
        }

        if description.lowercased().contains("decode") ||
           description.lowercased().contains("serialization") {
            return "결제 정보를 처리하는 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요."
        }

        return "결제 처리 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요."
    }

    static func paymentCancelledMessage(reason: String?) -> String {
        if let reason = reason, !reason.isEmpty {
            if reason.contains("사용자") || reason.contains("취소") {
                return "결제가 취소되었습니다."
            }
            return "\(reason)\n다시 시도하시겠습니까?"
        }
        return "결제가 취소되었습니다."
    }
}
