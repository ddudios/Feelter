//
//  ISO8601DateParser.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

/// ISO 8601 날짜 문자열 파싱 유틸리티
///
/// API 응답 날짜 형식:
/// - "9999-05-06T06:04:52.542Z" (밀리초 포함)
/// - "9999-05-06T06:04:52Z" (밀리초 없음)
enum ISO8601DateParser {

    /// ISO 8601 DateFormatter (밀리초 포함)
    private static let formatterWithMilliseconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds // 밀리초 포함
        ]
        return formatter
    }()

    /// ISO 8601 DateFormatter (밀리초 없음)
    private static let formatterWithoutMilliseconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// ISO 8601 문자열을 Date로 변환
    ///
    /// 변환 시도 순서:
    /// 1. 밀리초 포함 형식으로 시도
    /// 2. 밀리초 없는 형식으로 시도
    /// 3. 모두 실패하면 현재 시간 반환 (Fallback)
    ///
    /// - Parameter string: ISO 8601 형식의 날짜 문자열
    /// - Returns: Date 객체
    static func date(from string: String) -> Date {
        // 1. 밀리초 포함 형식 시도
        if let date = formatterWithMilliseconds.date(from: string) {
            return date
        }

        // 2. 밀리초 없는 형식 시도
        if let date = formatterWithoutMilliseconds.date(from: string) {
            return date
        }

        // 3. 파싱 실패 시 현재 시간 반환
        print("ISO8601 날짜 파싱 실패: \(string)")
        return Date()
    }

    /// Date를 ISO 8601 문자열로 변환
    ///
    /// - Parameter date: Date 객체
    /// - Returns: ISO 8601 형식의 문자열
    static func string(from date: Date) -> String {
        return formatterWithMilliseconds.string(from: date)
    }
}
