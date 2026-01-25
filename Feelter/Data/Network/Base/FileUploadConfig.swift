//
//  FileUploadConfig.swift
//  Feelter
//
//  Created by Suji Jang on 1/13/26.
//

import Foundation

/// 파일 업로드 설정
/// - 각 API의 업로드 제한사항을 정의
/// - 유효성 검사 제공
/// - MIME Type 자동 변환
struct FileUploadConfig {
    /// multipart/form-data의 파라미터 이름
    /// - 프로필: "profile"
    /// - 나머지: "files"
    let parameterName: String

    /// 허용된 확장자 (소문자)
    let allowedExtensions: [String]

    /// 최대 파일 크기 (바이트)
    let maxFileSize: Int

    /// 최대 파일 개수
    let maxFileCount: Int

    // MARK: - 미리 정의된 설정들

    /// 프로필 이미지 업로드 설정
    /// - 확장자: jpg, png, jpeg
    /// - 최대 크기: 1MB
    /// - 최대 개수: 1개
    static let profile = FileUploadConfig(
        parameterName: "profile",
        allowedExtensions: ["jpg", "png", "jpeg"],
        maxFileSize: 1 * 1024 * 1024,  // 1MB
        maxFileCount: 1
    )

    /// 필터 파일 업로드 설정
    /// - 확장자: jpg, png, jpeg
    /// - 최대 크기: 5MB
    /// - 최대 개수: 2개
    static let filter = FileUploadConfig(
        parameterName: "files",
        allowedExtensions: ["jpg", "png", "jpeg"],
        maxFileSize: 5 * 1024 * 1024,  // 5MB
        maxFileCount: 2
    )

    /// 포스트 파일 업로드 설정
    /// - 확장자: jpg, png, jpeg, gif, webp, mp4, mov, avi, mkv, wmv
    /// - 최대 크기: 5MB
    /// - 최대 개수: 5개
    static let post = FileUploadConfig(
        parameterName: "files",
        allowedExtensions: ["jpg", "png", "jpeg", "gif", "webp", "mp4", "mov", "avi", "mkv", "wmv"],
        maxFileSize: 5 * 1024 * 1024,  // 5MB
        maxFileCount: 5
    )

    /// 채팅 파일 업로드 설정
    /// - 확장자: 서버 제한이 있어도 클라이언트는 제한하지 않음
    /// - 최대 크기: 50MB
    /// - 최대 개수: 5개
    static let chat = FileUploadConfig(
        parameterName: "files",
        allowedExtensions: ["*"],
        maxFileSize: 50 * 1024 * 1024,  // 50MB
        maxFileCount: 5
    )

    /// 채팅 파일 업로드 설정 (대체 파라미터)
    /// - 일부 서버에서 files[] 형태만 허용하는 경우 대응
    static let chatArray = FileUploadConfig(
        parameterName: "files[]",
        allowedExtensions: ["*"],
        maxFileSize: 50 * 1024 * 1024,  // 50MB
        maxFileCount: 5
    )

    /// 채팅 파일 업로드 설정 (단일 파일 파라미터)
    /// - 일부 서버에서 file 단일 파라미터만 허용하는 경우 대응
    static let chatSingle = FileUploadConfig(
        parameterName: "file",
        allowedExtensions: ["*"],
        maxFileSize: 50 * 1024 * 1024,  // 50MB
        maxFileCount: 5
    )

    // MARK: - 유효성 검사

    /// 파일 데이터 배열이 유효한지 검사
    /// - Parameter dataList: 업로드할 파일 데이터 배열
    /// - Throws: FileUploadError
    func validate(_ dataList: [Data]) throws {
        // 1. 파일 개수 체크
        guard dataList.count <= maxFileCount else {
            throw FileUploadError.tooManyFiles(max: maxFileCount, actual: dataList.count)
        }

        guard !dataList.isEmpty else {
            throw FileUploadError.noFiles
        }

        // 2. 각 파일 크기 체크
        for (index, data) in dataList.enumerated() {
            guard data.count <= maxFileSize else {
                let sizeInMB = Double(data.count) / 1024.0 / 1024.0
                let maxSizeInMB = Double(maxFileSize) / 1024.0 / 1024.0
                throw FileUploadError.fileTooLarge(
                    index: index,
                    sizeInMB: sizeInMB,
                    maxSizeInMB: maxSizeInMB
                )
            }
        }
    }
}

// MARK: - 파일 업로드 에러

enum FileUploadError: LocalizedError {
    case noFiles
    case tooManyFiles(max: Int, actual: Int)
    case fileTooLarge(index: Int, sizeInMB: Double, maxSizeInMB: Double)
    case unsupportedExtension(extension: String, allowed: [String])
    case invalidFileExtensionCount(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .noFiles:
            return "업로드할 파일이 없습니다."
        case .tooManyFiles(let max, let actual):
            return "파일은 최대 \(max)개까지 업로드할 수 있습니다. (현재: \(actual)개)"
        case .fileTooLarge(let index, let size, let maxSize):
            return "\(index + 1)번째 파일이 너무 큽니다. (현재: \(String(format: "%.2f", size))MB, 최대: \(String(format: "%.1f", maxSize))MB)"
        case .unsupportedExtension(let ext, let allowed):
            return "지원하지 않는 파일 형식입니다. (\(ext)) 허용된 확장자: \(allowed.joined(separator: ", "))"
        case .invalidFileExtensionCount(let expected, let actual):
            return "파일 확장자 정보가 부족합니다. (필요: \(expected)개, 현재: \(actual)개)"
        }
    }
}

// MARK: - MIME Type 유틸리티

extension FileUploadConfig {
    /// 확장자로부터 MIME Type 추론
    /// - Parameter fileExtension: 파일 확장자 (대소문자 무관)
    /// - Returns: MIME Type 문자열
    static func mimeType(for fileExtension: String) -> String {
        let ext = fileExtension.lowercased()

        switch ext {
        // 이미지
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"

        // 동영상
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "avi":
            return "video/x-msvideo"
        case "mkv":
            return "video/x-matroska"
        case "wmv":
            return "video/x-ms-wmv"

        // 오디오
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"

        // 문서
        case "pdf":
            return "application/pdf"

        // 기본값 (알 수 없는 파일)
        default:
            return "application/octet-stream"
        }
    }
}
