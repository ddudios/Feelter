//
//  NetworkError.swift
//  Feelter
//
//  Created by Suji Jang on 12/22/25.
//

import Foundation

public enum NetworkError: Error {
    case urlError
    case invalid
    case failToDecode(String)
    case dataNil
    case serverError(Int, String)
    case requestFailed(String)
    
    public var description: String {
        switch self {
        case .urlError:
            "URL이 올바르지 않습니다"
        case .invalid:
            "응답값이 유효하지 않습니다"
        case .failToDecode(let description):
            "디코딩 에러\(description)"
        case .dataNil:
            "데이터가 없습니다"
        case let .serverError(statusCode, message):
            "서버에러 \(statusCode): \(message)"
        case .requestFailed(let message):
            "서버 요청 실패 \(message)"
        }
    }
}
