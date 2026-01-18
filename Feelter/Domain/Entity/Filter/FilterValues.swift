//
//  FilterValues.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct FilterValues: Equatable {
    var brightness: Double
    var exposure: Double
    var contrast: Double
    var saturation: Double
    var sharpness: Double
    var blur: Double
    var vignette: Double
    var noiseReduction: Double
    var highlights: Double
    var shadows: Double
    var temperature: Double
    var tint: Double
    var blackPoint: Double
}

extension FilterValues {
    /// 기본 필터 값
    /// FilterEditViewController가 구현되지 않았을 때 사용
    static let `default` = FilterValues(
        brightness: 0.0,
        exposure: 0.0,
        contrast: 1.0,
        saturation: 1.0,
        sharpness: 0.0,
        blur: 0.0,
        vignette: 0.0,
        noiseReduction: 0.0,
        highlights: 0.0,
        shadows: 0.0,
        temperature: 6500.0,
        tint: 0.0,
        blackPoint: 0.0
    )
}
