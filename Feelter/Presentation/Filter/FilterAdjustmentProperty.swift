//
//  FilterAdjustmentProperty.swift
//  Feelter
//
//  Created by Suji Jang on 1/14/26.
//

import UIKit

enum FilterAdjustmentProperty: CaseIterable {
    case brightness
    case exposure
    case contrast
    case saturation
    case sharpness
    case blur
    case vignette
    case noise
    case highlights
    case shadows
    case temperature
    case blackPoint
}

extension FilterAdjustmentProperty {
    static var ordered: [FilterAdjustmentProperty] {
        [
            .brightness, .exposure, .contrast, .saturation, .sharpness, .blur,
            .vignette, .noise, .highlights, .shadows, .temperature, .blackPoint
        ]
    }

    var title: String {
        switch self {
        case .brightness: return "BRIGHTNESS"
        case .exposure: return "EXPOSURE"
        case .contrast: return "CONTRAST"
        case .saturation: return "SATURATION"
        case .sharpness: return "SHARPNESS"
        case .blur: return "BLUR"
        case .vignette: return "VIGNETTE"
        case .noise: return "NOISE"
        case .highlights: return "HIGHLIGHTS"
        case .shadows: return "SHADOWS"
        case .temperature: return "TEMPERATURE"
        case .blackPoint: return "BLACK POINT"
        }
    }

    var icon: UIImage? {
        switch self {
        case .brightness: return UIImage.FilterProps.brightness
        case .exposure: return UIImage.FilterProps.exposure
        case .contrast: return UIImage.FilterProps.contrast
        case .saturation: return UIImage.FilterProps.saturation
        case .sharpness: return UIImage.FilterProps.sharpness
        case .blur: return UIImage.FilterProps.blur
        case .vignette: return UIImage.FilterProps.vignette
        case .noise: return UIImage.FilterProps.noise
        case .highlights: return UIImage.FilterProps.highlights
        case .shadows: return UIImage.FilterProps.shadows
        case .temperature: return UIImage.FilterProps.temperature
        case .blackPoint: return UIImage.FilterProps.blackPoint
        }
    }

    var defaultInternalValue: Double {
        switch self {
        case .brightness: return 0.0
        case .exposure: return 0.0
        case .contrast: return 1.0
        case .saturation: return 1.0
        case .sharpness: return 0.0
        case .blur: return 0.0
        case .vignette: return 0.0
        case .noise: return 0.0
        case .highlights: return 0.0
        case .shadows: return 0.0
        case .temperature: return 6500.0
        case .blackPoint: return 0.0
        }
    }

    var internalMinimumValue: Double {
        switch self {
        case .brightness: return -1.0
        case .exposure: return -4.0
        case .contrast: return 0.0
        case .saturation: return 0.0
        case .sharpness: return 0.0
        case .blur: return 0.0
        case .vignette: return 0.0
        case .noise: return 0.0
        case .highlights: return -1.0
        case .shadows: return -1.0
        case .temperature: return 2000.0
        case .blackPoint: return 0.0
        }
    }

    var internalMaximumValue: Double {
        switch self {
        case .brightness: return 1.0
        case .exposure: return 4.0
        case .contrast: return 4.0
        case .saturation: return 2.0
        case .sharpness: return 2.0
        case .blur: return 100.0
        case .vignette: return 1.0
        case .noise: return 1.0
        case .highlights: return 1.0
        case .shadows: return 1.0
        case .temperature: return 10000.0
        case .blackPoint: return 1.0
        }
    }

    var isBidirectional: Bool {
        switch self {
        case .blur, .sharpness, .vignette, .noise, .blackPoint:
            return false
        case .brightness, .exposure, .contrast, .saturation, .highlights, .shadows, .temperature:
            return true
        }
    }

    var sliderMinimumValue: Float {
        isBidirectional ? -10.0 : 0.0
    }

    var sliderMaximumValue: Float { 10.0 }

    var defaultSliderValue: Float {
        Float(sliderValue(forInternalValue: defaultInternalValue))
    }

    var supportsZeroSnap: Bool { isBidirectional }

    func internalValue(forSliderValue sliderValue: Float) -> Double {
        let sliderValue = clamp(Double(sliderValue), min: Double(sliderMinimumValue), max: Double(sliderMaximumValue))
        let minimumValue = internalMinimumValue
        let maximumValue = internalMaximumValue
        let defaultValue = defaultInternalValue

        if isBidirectional {
            if sliderValue >= 0 {
                let normalized = sliderValue / 10.0
                return defaultValue + (maximumValue - defaultValue) * normalized
            } else {
                let normalized = abs(sliderValue) / 10.0
                return defaultValue - (defaultValue - minimumValue) * normalized
            }
        }

        let normalized = sliderValue / 10.0
        return minimumValue + (maximumValue - minimumValue) * normalized
    }

    func sliderValue(forInternalValue internalValue: Double) -> Double {
        let internalValue = clamp(internalValue, min: internalMinimumValue, max: internalMaximumValue)
        let minimumValue = internalMinimumValue
        let maximumValue = internalMaximumValue
        let defaultValue = defaultInternalValue

        if isBidirectional {
            if internalValue >= defaultValue {
                let range = maximumValue - defaultValue
                guard range != 0 else { return 0 }
                let normalized = (internalValue - defaultValue) / range
                return normalized * 10.0
            } else {
                let range = defaultValue - minimumValue
                guard range != 0 else { return 0 }
                let normalized = (defaultValue - internalValue) / range
                return -normalized * 10.0
            }
        }

        let range = maximumValue - minimumValue
        guard range != 0 else { return 0 }
        let normalized = (internalValue - minimumValue) / range
        return normalized * 10.0
    }

    func displayValue(forInternalValue internalValue: Double) -> Double {
        let value = sliderValue(forInternalValue: internalValue)
        return abs(value) < 0.05 ? 0.0 : value
    }

    func internalValue(from values: FilterValues) -> Double {
        switch self {
        case .brightness: return values.brightness
        case .exposure: return values.exposure
        case .contrast: return values.contrast
        case .saturation: return values.saturation
        case .sharpness: return values.sharpness
        case .blur: return values.blur
        case .vignette: return values.vignette
        case .noise: return values.noiseReduction
        case .highlights: return values.highlights
        case .shadows: return values.shadows
        case .temperature: return values.temperature
        case .blackPoint: return values.blackPoint
        }
    }

    private func clamp(_ value: Double, min minimumValue: Double, max maximumValue: Double) -> Double {
        Swift.min(Swift.max(value, minimumValue), maximumValue)
    }
}
