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

    // [핵심] 필터 값을 받을 Subject
    // CurrentValueSubject를 사용하면 현재 상태를 추적할 수 있고, .value로 현재 값 접근 가능
    let filterValuesSubject = CurrentValueSubject<FilterValues, Never>(.default)
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupPipeline()
    }

    // 렌더링 파이프라인 설정
    private func setupPipeline() {
        filterValuesSubject
            // [Safety 1] 디바운스: 0.05초 동안 값 변화가 멈출 때까지 대기
            // 슬라이더를 0.1 -> 0.5 -> 0.9로 빠르게 움직이면 0.1, 0.5는 무시하고 0.9만 처리함
            // 이것만으로도 "작업 취소"와 유사한 효과(리소스 절약)를 냅니다.
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)

            // [Safety 2] 여기서부터 백그라운드 스레드(주방)로 보냄
            .receive(on: DispatchQueue.global(qos: .userInteractive))

            // [Safety 3] 렌더링 (순서 보장)
            // Combine의 map은 "직렬(Serial)"로 동작합니다.
            // 0.5 밝기 처리가 끝나기 전에는 절대 0.9 밝기 처리를 시작하지 않습니다.
            // 따라서 "0.9가 먼저 화면에 뜨고 나중에 0.5가 덮어씌우는" 버그가 원천 차단됩니다.
            .map { [weak self] (values: FilterValues) -> UIImage? in
                return self?.renderImage(with: values)
            }

            // 메인 스레드 복귀
            .receive(on: DispatchQueue.main)

            // UI 반영
            .sink { [weak self] image in
                self?.previewImage = image
            }
            .store(in: &cancellables)
    }

    // 렌더링 로직 분리 (순수 함수에 가깝게)
    private func renderImage(with values: FilterValues) -> UIImage? {
        guard let inputImage = smallCIImage else { return nil }

        var outputImage = inputImage

        // Brightness, Contrast, Saturation (CIColorControls)
        if values.brightness != 0.0 || values.contrast != 1.0 || values.saturation != 1.0 {
            brightnessFilter.inputImage = outputImage
            brightnessFilter.brightness = Float(values.brightness)
            brightnessFilter.contrast = Float(values.contrast)
            brightnessFilter.saturation = Float(values.saturation)
            if let result = brightnessFilter.outputImage {
                outputImage = result
            }
        }

        // Exposure
        if values.exposure != 0.0 {
            exposureFilter.inputImage = outputImage
            exposureFilter.ev = Float(values.exposure)
            if let result = exposureFilter.outputImage {
                outputImage = result
            }
        }

        // Highlights & Shadows
        if values.highlights != 0.0 || values.shadows != 0.0 {
            highlightsFilter.inputImage = outputImage
            highlightsFilter.highlightAmount = Float(values.highlights)
            highlightsFilter.shadowAmount = Float(values.shadows)
            if let result = highlightsFilter.outputImage {
                outputImage = result
            }
        }

        // Temperature & Tint
        if values.temperature != 6500 || values.tint != 0.0 {
            temperatureFilter.inputImage = outputImage
            temperatureFilter.neutral = CIVector(x: CGFloat(values.temperature), y: CGFloat(values.tint))
            temperatureFilter.targetNeutral = CIVector(x: 6500, y: 0)
            if let result = temperatureFilter.outputImage {
                outputImage = result
            }
        }

        // Sharpness
        if values.sharpness > 0.0 {
            sharpenFilter.inputImage = outputImage
            sharpenFilter.sharpness = Float(values.sharpness)
            if let result = sharpenFilter.outputImage {
                outputImage = result
            }
        }

        // Vignette
        if values.vignette > 0.0 {
            vignetteFilter.inputImage = outputImage
            vignetteFilter.intensity = Float(values.vignette)
            vignetteFilter.radius = 1.0
            if let result = vignetteFilter.outputImage {
                outputImage = result
            }
        }

        // Blur
        if values.blur > 0.0 {
            blurFilter.inputImage = outputImage
            blurFilter.radius = Float(values.blur)
            if let result = blurFilter.outputImage {
                outputImage = result
            }
        }

        // Noise Reduction
        if values.noiseReduction > 0.0 {
            noiseReductionFilter.inputImage = outputImage
            noiseReductionFilter.noiseLevel = Float(values.noiseReduction)
            noiseReductionFilter.sharpness = 0.4
            if let result = noiseReductionFilter.outputImage {
                outputImage = result
            }
        }

        // Black Point (using Tone Curve)
        if values.blackPoint > 0.0 {
            toneCurveFilter.inputImage = outputImage
            toneCurveFilter.point0 = CGPoint(x: 0, y: CGFloat(values.blackPoint))
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

        // 이미지 로딩 완료되면 초기값(기본 필터 값)으로 한 번 렌더링 트리거
        filterValuesSubject.send(.default)
    }

    // URL이 없고 UIImage만 있는 경우를 위한 대비책 (보조용)
    func setImage(from image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        self.originalCIImage = ciImage
        self.smallCIImage = downsampleCIImage(ciImage, targetLength: 1024)
        filterValuesSubject.send(.default)
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
        var current = filterValuesSubject.value
        current.brightness = Double(value)
        filterValuesSubject.send(current)
    }

    func updateContrast(value: Float) {
        var current = filterValuesSubject.value
        current.contrast = Double(value)
        filterValuesSubject.send(current)
    }

    func updateSaturation(value: Float) {
        var current = filterValuesSubject.value
        current.saturation = Double(value)
        filterValuesSubject.send(current)
    }

    func updateExposure(value: Float) {
        var current = filterValuesSubject.value
        current.exposure = Double(value)
        filterValuesSubject.send(current)
    }

    func updateHighlights(value: Float) {
        var current = filterValuesSubject.value
        current.highlights = Double(value)
        filterValuesSubject.send(current)
    }

    func updateShadows(value: Float) {
        var current = filterValuesSubject.value
        current.shadows = Double(value)
        filterValuesSubject.send(current)
    }

    func updateTemperature(value: Float) {
        var current = filterValuesSubject.value
        current.temperature = Double(value)
        filterValuesSubject.send(current)
    }

    func updateTint(value: Float) {
        var current = filterValuesSubject.value
        current.tint = Double(value)
        filterValuesSubject.send(current)
    }

    func updateSharpness(value: Float) {
        var current = filterValuesSubject.value
        current.sharpness = Double(value)
        filterValuesSubject.send(current)
    }

    func updateVignette(value: Float) {
        var current = filterValuesSubject.value
        current.vignette = Double(value)
        filterValuesSubject.send(current)
    }

    func updateBlur(value: Float) {
        var current = filterValuesSubject.value
        current.blur = Double(value)
        filterValuesSubject.send(current)
    }

    func updateNoiseReduction(value: Float) {
        var current = filterValuesSubject.value
        current.noiseReduction = Double(value)
        filterValuesSubject.send(current)
    }

    func updateBlackPoint(value: Float) {
        var current = filterValuesSubject.value
        current.blackPoint = Double(value)
        filterValuesSubject.send(current)
    }

    // 현재 적용된 필터의 최종 이미지 반환
    func getFinalImage() -> UIImage? {
        return previewImage
    }

    // 모든 필터 초기화
    func resetAllFilters() {
        filterValuesSubject.send(.default)
    }

    // [저장 기능] 최종 저장할 때는 원본에 적용!
    // 이 함수는 사용자가 '저장' 버튼을 눌렀을 때 호출하면 됩니다.
    func saveOriginalImage() -> UIImage? {
        guard let inputImage = originalCIImage else { return nil }

        // 현재 필터 값 가져오기 (.value로 현재 상태 접근)
        let values = filterValuesSubject.value

        var outputImage = inputImage

        // 원본에 모든 필터 값 적용 (renderImage와 동일한 로직)
        // Brightness, Contrast, Saturation (CIColorControls)
        if values.brightness != 0.0 || values.contrast != 1.0 || values.saturation != 1.0 {
            brightnessFilter.inputImage = outputImage
            brightnessFilter.brightness = Float(values.brightness)
            brightnessFilter.contrast = Float(values.contrast)
            brightnessFilter.saturation = Float(values.saturation)
            if let result = brightnessFilter.outputImage {
                outputImage = result
            }
        }

        // Exposure
        if values.exposure != 0.0 {
            exposureFilter.inputImage = outputImage
            exposureFilter.ev = Float(values.exposure)
            if let result = exposureFilter.outputImage {
                outputImage = result
            }
        }

        // Highlights & Shadows
        if values.highlights != 0.0 || values.shadows != 0.0 {
            highlightsFilter.inputImage = outputImage
            highlightsFilter.highlightAmount = Float(values.highlights)
            highlightsFilter.shadowAmount = Float(values.shadows)
            if let result = highlightsFilter.outputImage {
                outputImage = result
            }
        }

        // Temperature & Tint
        if values.temperature != 6500 || values.tint != 0.0 {
            temperatureFilter.inputImage = outputImage
            temperatureFilter.neutral = CIVector(x: CGFloat(values.temperature), y: CGFloat(values.tint))
            temperatureFilter.targetNeutral = CIVector(x: 6500, y: 0)
            if let result = temperatureFilter.outputImage {
                outputImage = result
            }
        }

        // Sharpness
        if values.sharpness > 0.0 {
            sharpenFilter.inputImage = outputImage
            sharpenFilter.sharpness = Float(values.sharpness)
            if let result = sharpenFilter.outputImage {
                outputImage = result
            }
        }

        // Vignette
        if values.vignette > 0.0 {
            vignetteFilter.inputImage = outputImage
            vignetteFilter.intensity = Float(values.vignette)
            vignetteFilter.radius = 1.0
            if let result = vignetteFilter.outputImage {
                outputImage = result
            }
        }

        // Blur
        if values.blur > 0.0 {
            blurFilter.inputImage = outputImage
            blurFilter.radius = Float(values.blur)
            if let result = blurFilter.outputImage {
                outputImage = result
            }
        }

        // Noise Reduction
        if values.noiseReduction > 0.0 {
            noiseReductionFilter.inputImage = outputImage
            noiseReductionFilter.noiseLevel = Float(values.noiseReduction)
            noiseReductionFilter.sharpness = 0.4
            if let result = noiseReductionFilter.outputImage {
                outputImage = result
            }
        }

        // Black Point (using Tone Curve)
        if values.blackPoint > 0.0 {
            toneCurveFilter.inputImage = outputImage
            toneCurveFilter.point0 = CGPoint(x: 0, y: CGFloat(values.blackPoint))
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
