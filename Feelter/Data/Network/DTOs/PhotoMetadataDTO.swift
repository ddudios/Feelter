//
//  PhotoMetadataDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct PhotoMetadataDTO: Codable {
    let camera: String
    let lensInfo: String
    let focalLength: Int
    let aperture: Double
    let iso: Int
    let shutterSpeed: String
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSize: Int
    let format: String
    let dateTimeOriginal: String
    let latitude: Double?
    let longitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case camera, aperture, iso, format, latitude, longitude
        case lensInfo = "lens_info"
        case focalLength = "focal_length"
        case shutterSpeed = "shutter_speed"
        case pixelWidth = "pixel_width"
        case pixelHeight = "pixel_height"
        case fileSize = "file_size"
        case dateTimeOriginal = "date_time_original"
    }
}

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
            takenDate: dateTimeOriginal.toDate() ?? Date()
        )
    }
}
