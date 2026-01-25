//
//  Video.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation

/// 목록 조회용 (가벼운 모델)
struct VideoSummary: Identifiable, Hashable {
    let id: String
    let fileName: String
    let title: String
    let description: String
    let duration: Double
    let thumbnailURL: String
    let availableQualities: [String]
    let viewCount: Int
    let likeCount: Int
    let isLiked: Bool
    let createdAt: Date
}

/// 스트리밍 정보
struct VideoStream {
    let id: String
    let streamURL: String
    let qualities: [VideoQuality]
    let subtitles: [VideoSubtitle]
}

struct VideoQuality: Hashable {
    let quality: String
    let url: String
}

struct VideoSubtitle: Hashable {
    let language: String
    let name: String
    let isDefault: Bool
    let url: String
}

/// 자막 아이템
struct SubtitleItem: Hashable, Identifiable {
    let id = UUID()
    let startTime: Double
    let endTime: Double
    let text: String

    func contains(time: Double) -> Bool {
        return time >= startTime && time < endTime
    }
}

/// WebVTT 파싱 유틸리티
struct WebVTTParser {
    static func parse(_ content: String) -> [SubtitleItem] {
        var items: [SubtitleItem] = []

        let lines = content.components(separatedBy: .newlines)
        var currentStartTime: Double?
        var currentEndTime: Double?
        var currentText = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 시간 라인 파싱 (예: 00:00.000 --> 00:01.034)
            if trimmed.contains("-->") {
                // 이전 자막이 있으면 저장
                if let start = currentStartTime, let end = currentEndTime, !currentText.isEmpty {
                    items.append(SubtitleItem(startTime: start, endTime: end, text: currentText.trimmingCharacters(in: .whitespaces)))
                    currentText = ""
                }

                let components = trimmed.components(separatedBy: "-->")
                if components.count == 2 {
                    currentStartTime = parseTimestamp(components[0].trimmingCharacters(in: .whitespaces))
                    currentEndTime = parseTimestamp(components[1].trimmingCharacters(in: .whitespaces))
                }
            }
            // 텍스트 라인
            else if !trimmed.isEmpty && trimmed != "WEBVTT" && !trimmed.allSatisfy({ $0.isNumber }) {
                if !currentText.isEmpty {
                    currentText += "\n"
                }
                currentText += trimmed
            }
        }

        // 마지막 자막 저장
        if let start = currentStartTime, let end = currentEndTime, !currentText.isEmpty {
            items.append(SubtitleItem(startTime: start, endTime: end, text: currentText.trimmingCharacters(in: .whitespaces)))
        }

        return items
    }

    private static func parseTimestamp(_ timestamp: String) -> Double {
        // 형식: 00:00.000 또는 00:00:00.000
        let components = timestamp.components(separatedBy: ":")

        if components.count == 2 {
            // mm:ss.SSS
            let minutes = Double(components[0]) ?? 0
            let secondsParts = components[1].components(separatedBy: ".")
            let seconds = Double(secondsParts[0]) ?? 0
            let milliseconds = secondsParts.count > 1 ? Double(secondsParts[1]) ?? 0 : 0
            return minutes * 60 + seconds + milliseconds / 1000
        } else if components.count == 3 {
            // hh:mm:ss.SSS
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let secondsParts = components[2].components(separatedBy: ".")
            let seconds = Double(secondsParts[0]) ?? 0
            let milliseconds = secondsParts.count > 1 ? Double(secondsParts[1]) ?? 0 : 0
            return hours * 3600 + minutes * 60 + seconds + milliseconds / 1000
        }

        return 0
    }
}
