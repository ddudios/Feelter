//
//  FilterValuesDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct FilterValuesDTO: Codable {
    let brightness: Double
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let sharpness: Double
    let blur: Double?
    let vignette: Double?
    let noiseReduction: Double?
    let highlights: Double?
    let shadows: Double?
    let temperature: Double?
    let blackPoint: Double?
    
    enum CodingKeys: String, CodingKey {
        case brightness, exposure, contrast, saturation, sharpness, blur, vignette, highlights, shadows, temperature
        case noiseReduction = "noise_reduction"
        case blackPoint = "black_point"
    }
}

extension FilterValuesDTO {
    func toDomain() -> FilterValues {
        return FilterValues(
            brightness: brightness,
            exposure: exposure,
            contrast: contrast,
            saturation: saturation,
            sharpness: sharpness,
            blur: blur ?? 0,
            vignette: vignette ?? 0,
            noiseReduction: noiseReduction ?? 0,
            highlights: highlights ?? 0,
            shadows: shadows ?? 0,
            temperature: temperature ?? 0,
            blackPoint: blackPoint ?? 0
        )
    }
}
