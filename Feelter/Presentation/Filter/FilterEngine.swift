//
//  FilterEngine.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
class FilterEngine: ObservableObject {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    // 원본 (메모리를 거의 차지하지 않음)
    private var originalCIImage: CIImage?

    private let brightnessFilter = CIFilter.colorControls()
    private let contrastFilter = CIFilter.colorControls()
    private let saturationFilter = CIFilter.colorControls()
    private let exposureFilter = CIFilter.exposureAdjust()
    private let highlightsFilter = CIFilter.highlightShadowAdjust()
    private let shadowsFilter = CIFilter.highlightShadowAdjust()
    private let temperatureFilter = CIFilter.temperatureAndTint()
    private let tintFilter = CIFilter.temperatureAndTint()
    private let sharpenFilter = CIFilter.sharpenLuminance()
    private let vignetteFilter = CIFilter.vignette()
    private let blurFilter = CIFilter.gaussianBlur()
    private let noiseReductionFilter = CIFilter.noiseReduction()
    private let toneCurveFilter = CIFilter.toneCurve()

    @Published var previewImage: UIImage?

    // 필터 값 저장 (FilterAdjustmentProperty의 defaultInternalValue 참고)
    private var brightness: Float = 0.0
    private var contrast: Float = 1.0
    private var saturation: Float = 1.0
    private var exposure: Float = 0.0
    private var highlights: Float = 0.0
    private var shadows: Float = 0.0
    private var temperature: Float = 6500
    private var tint: Float = 0.0
    private var sharpness: Float = 0.0
    private var vignette: Float = 0.0
    private var blur: Float = 0.0
    private var noiseReduction: Float = 0.0
    private var blackPoint: Float = 0.0

    // 이미지를 통째로 받는 게 아니라, 파일의 '위치(URL)'만 받습니다.
    // 갤러리(PHPicker)에서 선택한 사진의 URL을 여기로 넘겨주면 됩니다.
    func setImage(from url: URL) {
        // contentsOf: url -> 이 시점엔 메모리에 로딩하지 않고 준비만 합니다. (Lazy)
        guard let ciImage = CIImage(contentsOf: url) else { return }

        self.originalCIImage = ciImage

        // 초기화 시 한 번 그려주기
        applyFilters()
    }

    // URL이 없고 UIImage만 있는 경우를 위한 대비책 (보조용)
    func setImage(from image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        self.originalCIImage = ciImage
        applyFilters()
    }

    func updateBrightness(value: Float) {
        brightness = value
        applyFilters()
    }

    func updateContrast(value: Float) {
        contrast = value
        applyFilters()
    }

    func updateSaturation(value: Float) {
        saturation = value
        applyFilters()
    }

    func updateExposure(value: Float) {
        exposure = value
        applyFilters()
    }

    func updateHighlights(value: Float) {
        highlights = value
        applyFilters()
    }

    func updateShadows(value: Float) {
        shadows = value
        applyFilters()
    }

    func updateTemperature(value: Float) {
        temperature = value
        applyFilters()
    }

    func updateTint(value: Float) {
        tint = value
        applyFilters()
    }

    func updateSharpness(value: Float) {
        sharpness = value
        applyFilters()
    }

    func updateVignette(value: Float) {
        vignette = value
        applyFilters()
    }

    func updateBlur(value: Float) {
        blur = value
        applyFilters()
    }

    func updateNoiseReduction(value: Float) {
        noiseReduction = value
        applyFilters()
    }

    func updateBlackPoint(value: Float) {
        blackPoint = value
        applyFilters()
    }

    private func applyFilters() {
        guard let inputImage = originalCIImage else { return }

        var outputImage = inputImage

        // Brightness, Contrast, Saturation (CIColorControls)
        if brightness != 0.0 || contrast != 1.0 || saturation != 1.0 {
            brightnessFilter.inputImage = outputImage
            brightnessFilter.brightness = brightness
            brightnessFilter.contrast = contrast
            brightnessFilter.saturation = saturation
            if let result = brightnessFilter.outputImage {
                outputImage = result
            }
        }

        // Exposure
        if exposure != 0.0 {
            exposureFilter.inputImage = outputImage
            exposureFilter.ev = exposure
            if let result = exposureFilter.outputImage {
                outputImage = result
            }
        }

        // Highlights & Shadows
        if highlights != 0.0 || shadows != 0.0 {
            highlightsFilter.inputImage = outputImage
            highlightsFilter.highlightAmount = highlights
            highlightsFilter.shadowAmount = shadows
            if let result = highlightsFilter.outputImage {
                outputImage = result
            }
        }

        // Temperature & Tint
        if temperature != 6500 || tint != 0.0 {
            temperatureFilter.inputImage = outputImage
            temperatureFilter.neutral = CIVector(x: CGFloat(temperature), y: CGFloat(tint))
            temperatureFilter.targetNeutral = CIVector(x: 6500, y: 0)
            if let result = temperatureFilter.outputImage {
                outputImage = result
            }
        }

        // Sharpness
        if sharpness > 0.0 {
            sharpenFilter.inputImage = outputImage
            sharpenFilter.sharpness = sharpness
            if let result = sharpenFilter.outputImage {
                outputImage = result
            }
        }

        // Vignette
        if vignette > 0.0 {
            vignetteFilter.inputImage = outputImage
            vignetteFilter.intensity = vignette
            vignetteFilter.radius = 1.0
            if let result = vignetteFilter.outputImage {
                outputImage = result
            }
        }

        // Blur
        if blur > 0.0 {
            blurFilter.inputImage = outputImage
            blurFilter.radius = blur
            if let result = blurFilter.outputImage {
                outputImage = result
            }
        }

        // Noise Reduction
        if noiseReduction > 0.0 {
            noiseReductionFilter.inputImage = outputImage
            noiseReductionFilter.noiseLevel = noiseReduction
            noiseReductionFilter.sharpness = 0.4
            if let result = noiseReductionFilter.outputImage {
                outputImage = result
            }
        }

        // Black Point (using Tone Curve)
        if blackPoint > 0.0 {
            toneCurveFilter.inputImage = outputImage
            // 블랙 포인트를 조정하여 어두운 영역을 조절
            toneCurveFilter.point0 = CGPoint(x: 0, y: CGFloat(blackPoint))
            toneCurveFilter.point1 = CGPoint(x: 0.25, y: 0.25)
            toneCurveFilter.point2 = CGPoint(x: 0.5, y: 0.5)
            toneCurveFilter.point3 = CGPoint(x: 0.75, y: 0.75)
            toneCurveFilter.point4 = CGPoint(x: 1, y: 1)
            if let result = toneCurveFilter.outputImage {
                outputImage = result
            }
        }

        // 여기서 렌더링 할 때 진짜 메모리를 씁니다.
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            DispatchQueue.main.async {
                self.previewImage = UIImage(cgImage: cgImage)
            }
        }
    }

    // 현재 적용된 필터의 최종 이미지 반환
    func getFinalImage() -> UIImage? {
        return previewImage
    }

    // 모든 필터 초기화
    func resetAllFilters() {
        brightness = 0.0
        contrast = 1.0
        saturation = 1.0
        exposure = 0.0
        highlights = 0.0
        shadows = 0.0
        temperature = 6500
        tint = 0.0
        sharpness = 0.0
        vignette = 0.0
        blur = 0.0
        noiseReduction = 0.0
        blackPoint = 0.0
        applyFilters()
    }
}
