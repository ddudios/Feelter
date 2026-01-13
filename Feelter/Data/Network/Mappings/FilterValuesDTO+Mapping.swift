//
//  FilterValuesDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension FilterValuesDTO {
    /// FilterValuesDTO (DTO) → FilterValues (Domain) 변환
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

extension FilterValues {
    /// FilterValues (Domain) → FilterValuesDTO (DTO) 변환
    func toDTO() -> FilterValuesDTO {
        return FilterValuesDTO(
            brightness: brightness,
            exposure: exposure,
            contrast: contrast,
            saturation: saturation,
            sharpness: sharpness,
            blur: blur,
            vignette: vignette,
            noiseReduction: noiseReduction,
            highlights: highlights,
            shadows: shadows,
            temperature: temperature,
            blackPoint: blackPoint
        )
    }
}
