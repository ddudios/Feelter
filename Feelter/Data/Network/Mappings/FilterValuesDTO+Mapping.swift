//
//  FilterValuesDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

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
