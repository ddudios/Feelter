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
