//
//  FilterValues.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

struct FilterValues {
    let brightness: Double
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let sharpness: Double
    let blur: Double
    let vignette: Double
    let noiseReduction: Double
    let highlights: Double
    let shadows: Double
    let temperature: Double
    let blackPoint: Double
}

extension FilterValues {
    /// 기본 필터 값 (모든 값 0으로 초기화)
    /// FilterEditViewController가 구현되지 않았을 때 사용
    static let `default` = FilterValues(
        brightness: 0.0,
        exposure: 0.0,
        contrast: 0.0,
        saturation: 0.0,
        sharpness: 0.0,
        blur: 0.0,
        vignette: 0.0,
        noiseReduction: 0.0,
        highlights: 0.0,
        shadows: 0.0,
        temperature: 0.0,
        blackPoint: 0.0
    )
}
