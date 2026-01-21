//
//  UploadFile.swift
//  Feelter
//
//  Created by Suji Jang on 1/23/26.
//

import Foundation

struct UploadFile {
    let data: Data
    let fileExtension: String

    var normalizedFileExtension: String {
        let trimmed = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix(".") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    var isVideo: Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "m4v"]
        return videoExtensions.contains(normalizedFileExtension)
    }
}
