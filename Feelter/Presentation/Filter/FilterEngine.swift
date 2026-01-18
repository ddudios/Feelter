//
//  FilterEngine.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Combine

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

    // [핵심] 렌더링 트리거 Subject - 어떤 값이 변경되든 이것으로 신호를 보냄
    private let renderTrigger = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

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

    init() {
        setupPipeline()
    }

    // 렌더링 파이프라인 설정
    private func setupPipeline() {
        renderTrigger
            // 1. [최적화] 디바운스: 값이 막 들어와도 0.05초 동안 조용할 때까지 기다림
            // 슬라이더를 미친듯이 흔들 때 렌더링을 안 해서 배터리/발열을 잡음
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)

            // 2. 여기서부터 백그라운드 스레드로 보냄
            .receive(on: DispatchQueue.global(qos: .userInteractive))

            // 3. 무거운 렌더링 작업 (Map)
            .map { [weak self] _ -> UIImage? in
                return self?.renderImage()
            }

            // 4. 결과가 나오면 다시 메인 스레드로 복귀
            .receive(on: DispatchQueue.main)

            // 5. 이미지 뷰에 할당
            .sink { [weak self] image in
                self?.previewImage = image
            }
            .store(in: &cancellables)
    }

    // 렌더링 로직 분리 (순수 함수에 가깝게)
    private func renderImage() -> UIImage? {
        guard let inputImage = smallCIImage else { return nil }

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
            toneCurveFilter.point0 = CGPoint(x: 0, y: CGFloat(blackPoint))
            toneCurveFilter.point1 = CGPoint(x: 0.25, y: 0.25)
            toneCurveFilter.point2 = CGPoint(x: 0.5, y: 0.5)
            toneCurveFilter.point3 = CGPoint(x: 0.75, y: 0.75)
            toneCurveFilter.point4 = CGPoint(x: 1, y: 1)
            if let result = toneCurveFilter.outputImage {
                outputImage = result
            }
        }

        // 렌더링 (백그라운드 스레드에서 실행됨)
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

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

        // 초기화 시 한 번 그려주기 (렌더링 트리거 발동)
        renderTrigger.send()
    }

    // URL이 없고 UIImage만 있는 경우를 위한 대비책 (보조용)
    func setImage(from image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        self.originalCIImage = ciImage
        self.smallCIImage = downsampleCIImage(ciImage, targetLength: 1024)
        renderTrigger.send()
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
        renderTrigger.send()
    }

    func updateContrast(value: Float) {
        contrast = value
        renderTrigger.send()
    }

    func updateSaturation(value: Float) {
        saturation = value
        renderTrigger.send()
    }

    func updateExposure(value: Float) {
        exposure = value
        renderTrigger.send()
    }

    func updateHighlights(value: Float) {
        highlights = value
        renderTrigger.send()
    }

    func updateShadows(value: Float) {
        shadows = value
        renderTrigger.send()
    }

    func updateTemperature(value: Float) {
        temperature = value
        renderTrigger.send()
    }

    func updateTint(value: Float) {
        tint = value
        renderTrigger.send()
    }

    func updateSharpness(value: Float) {
        sharpness = value
        renderTrigger.send()
    }

    func updateVignette(value: Float) {
        vignette = value
        renderTrigger.send()
    }

    func updateBlur(value: Float) {
        blur = value
        renderTrigger.send()
    }

    func updateNoiseReduction(value: Float) {
        noiseReduction = value
        renderTrigger.send()
    }

    func updateBlackPoint(value: Float) {
        blackPoint = value
        renderTrigger.send()
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
        renderTrigger.send()
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
