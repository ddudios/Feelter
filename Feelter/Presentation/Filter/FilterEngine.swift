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

    // 원본 (고화질, 저장용)
    private var originalCIImage: CIImage?

    // 축소본 (저화질, 화면 표시 및 편집용)
    private var smallCIImage: CIImage?

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

        // 원본 보관
        self.originalCIImage = ciImage

        // 다운샘플링 실행 (화면용 작은 이미지 만들기)
        // 목표: 긴 쪽의 길이가 1024 픽셀 정도면 충분함 (아이폰 화면용)
        self.smallCIImage = downsampleCIImage(ciImage, targetLength: 1024)

        // 초기화 시 한 번 그려주기 (작은 이미지로 필터 적용)
        applyFilters()
    }

    // URL이 없고 UIImage만 있는 경우를 위한 대비책 (보조용)
    func setImage(from image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        self.originalCIImage = ciImage
        self.smallCIImage = downsampleCIImage(ciImage, targetLength: 1024)
        applyFilters()
    }

    // 다운샘플링 함수 (Core Image 방식)
    private func downsampleCIImage(_ image: CIImage, targetLength: CGFloat) -> CIImage? {
        // 이미지의 현재 크기
        let extent = image.extent
        let maxDimension = max(extent.width, extent.height)

        // 이미지가 목표보다 작으면 굳이 줄일 필요 없음
        if maxDimension <= targetLength {
            return image
        }

        // 줄여야 할 비율 계산 (예: 4000px -> 1000px 이면 0.25배)
        let scale = targetLength / maxDimension

        // 변환 행렬(Transform Matrix)을 사용해 크기 조절 필터 적용
        // 이 방식이 메모리 효율이 가장 좋음
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        return image.transformed(by: transform)
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
        // [중요] 필터 적용 대상이 'original'이 아니라 'small'입니다!
        guard let inputImage = smallCIImage else { return }

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

    // [저장 기능] 최종 저장할 때는 원본에 적용!
    // 이 함수는 사용자가 '저장' 버튼을 눌렀을 때 호출하면 됩니다.
    func saveOriginalImage() -> UIImage? {
        guard let inputImage = originalCIImage else { return nil }

        var outputImage = inputImage

        // 원본에 모든 필터 값 적용 (applyFilters와 동일한 로직)
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
            toneCurveFilter.point0 = CGPoint(x: 0, y: CGFloat(blackPoint))
            toneCurveFilter.point1 = CGPoint(x: 0.25, y: 0.25)
            toneCurveFilter.point2 = CGPoint(x: 0.5, y: 0.5)
            toneCurveFilter.point3 = CGPoint(x: 0.75, y: 0.75)
            toneCurveFilter.point4 = CGPoint(x: 1, y: 1)
            if let result = toneCurveFilter.outputImage {
                outputImage = result
            }
        }

        // 고화질 렌더링 (시간이 좀 걸려도 됨)
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
