//
//  PhotoMetadata.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct PhotoMetadata {
    let camera: String
    let lensInfo: String
    let focalLength: Int
    let aperture: Double
    let iso: Int
    let shutterSpeed: String
    let resolution: String // pixelWidth x pixelHeight 조합
    let fileSize: String   // MB 단위 등으로 변환해서 저장해도 됨
    let takenDate: Date?
    
    // 빈 객체 (상세 정보가 없을 때 사용)
    static let empty = PhotoMetadata(
        camera: "-", lensInfo: "-", focalLength: 0, aperture: 0, iso: 0,
        shutterSpeed: "-", resolution: "-", fileSize: "-", takenDate: nil
    )
}
