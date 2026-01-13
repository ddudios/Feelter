//
//  PhotoMetadata+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import Foundation

extension PhotoMetadata {
    /// PhotoMetadata (Domain) → PhotoMetadataDTO (Network DTO) 변환
    ///
    /// 변환 작업:
    /// 1. Date → ISO 8601 String (date_time_original)
    /// 2. fileSizeBytes → file_size
    /// 3. format: "JPEG" (기본값, 추후 실제 포맷으로 변경)
    ///
    /// - Returns: PhotoMetadataDTO
    func toDTO() -> PhotoMetadataDTO {
        let dateString = takenDate.map { ISO8601DateParser.string(from: $0) }
            ?? ISO8601DateParser.string(from: Date())

        return PhotoMetadataDTO(
            camera: camera,
            lensInfo: lensInfo,
            focalLength: focalLength,
            aperture: aperture,
            iso: iso,
            shutterSpeed: shutterSpeed,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            fileSize: fileSizeBytes,
            format: "JPEG", // 기본값, 추후 실제 이미지 포맷으로 변경
            dateTimeOriginal: dateString,
            latitude: latitude,
            longitude: longitude
        )
    }
}
