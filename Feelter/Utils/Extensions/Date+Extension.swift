//
//  Date+Extension.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

extension String {
    // "yyyy-MM-dd'T'HH:mm:ss.SSSZ" 형태의 ISO8601 문자열을 Date로 변환
    func toDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: self)
    }
}

extension Date {
    func formatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}
