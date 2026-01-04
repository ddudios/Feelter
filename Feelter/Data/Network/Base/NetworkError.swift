//
//  NetworkError.swift
//  Feelter
//
//  Created by Suji Jang on 12/22/25.
//

import Foundation

public enum NetworkError: Error {
    case invalidURL
    case serverError(statusCode: Int) // 500번대 에러
    case clientError(statusCode: Int, message: String?) // 400번대 에러
    case decodingError // DTO 변환 실패
    case unknownError(String) // 알 수 없는 에러
    
    var errorDescription: String {
        switch self {
        case .invalidURL: return "유효하지 않은 URL입니다."
        case .serverError(let code): return "서버 점검 중입니다. (코드: \(code))"
        case .clientError(_, let message): return message ?? "잘못된 요청입니다."
        case .decodingError: return "데이터를 불러오는 데 실패했습니다."
        case .unknownError(let msg): return "알 수 없는 오류: \(msg)"
        }
    }
}
