//
//  MessageSendStatus.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation


enum MessageSendStatus: String, Codable {
    /// 전송 중 (API 요청 진행 중)
    case sending

    /// 전송 완료 (서버 응답 200 OK)
    case sent

    /// 전송 실패 (네트워크 에러, 서버 에러 등)
    case failed
}

// MARK: - UI Helper
extension MessageSendStatus {
    /// UI에 표시할 텍스트
    var displayText: String {
        switch self {
        case .sending:
            return "전송 중..."
        case .sent:
            return "전송 완료"
        case .failed:
            return "전송 실패"
        }
    }

    /// UI에 표시할 아이콘 (SF Symbol)
    var iconName: String {
        switch self {
        case .sending:
            return "arrow.up.circle" // 전송 중
        case .sent:
            return "checkmark.circle.fill" // 체크 마크
        case .failed:
            return "exclamationmark.triangle.fill" // 경고
        }
    }

    /// 재전송 버튼 표시 여부
    var shouldShowRetryButton: Bool {
        return self == .failed
    }
}
