//
//  PhotoMetadataDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension PhotoMetadataDTO {
    func toDomain() -> PhotoMetadata {
        return PhotoMetadata(
            camera: camera,
            lensInfo: lensInfo,
            focalLength: focalLength,
            aperture: aperture,
            iso: iso,
            shutterSpeed: shutterSpeed,
            resolution: "\(pixelWidth) x \(pixelHeight)",
            fileSize: ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file),
            takenDate: dateTimeOriginal.toDate() ?? Date(),
            latitude: latitude,
            longitude: longitude
        )
    }
}
