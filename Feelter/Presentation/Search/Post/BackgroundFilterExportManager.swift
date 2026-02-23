//
//  BackgroundFilterExportManager.swift
//  Feelter
//
//  Created by Codex on 2/23/26.
//

@preconcurrency import UIKit
import Photos
import Combine

struct BackgroundFilterExportRequest: @unchecked Sendable {
    let originalImage: UIImage
    let filterValues: FilterValues
    let appliedFilter: FilterDetail?
}

enum BackgroundFilterExportEvent {
    case succeeded
    case failed(String)
}

enum BackgroundFilterExportError: LocalizedError {
    case imageRenderFailed
    case photoLibraryPermissionDenied
    case photoLibrarySaveFailed

    var errorDescription: String? {
        switch self {
        case .imageRenderFailed:
            return "필터 적용 이미지를 생성하지 못했습니다."
        case .photoLibraryPermissionDenied:
            return "사진첩 저장 권한이 필요합니다."
        case .photoLibrarySaveFailed:
            return "사진첩 저장에 실패했습니다."
        }
    }
}

final class BackgroundFilterExportManager {

    static let shared = BackgroundFilterExportManager()

    var events: AnyPublisher<BackgroundFilterExportEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private let eventSubject = PassthroughSubject<BackgroundFilterExportEvent, Never>()

    private init() { }

    func export(request: BackgroundFilterExportRequest) {
        Task { [eventSubject] in
            let resultEvent = await Self.processExport(request: request)
            await MainActor.run {
                eventSubject.send(resultEvent)
            }
        }
    }

    private static func processExport(request: BackgroundFilterExportRequest) async -> BackgroundFilterExportEvent {
        guard let renderedImage = await Task.detached(priority: .userInitiated, operation: {
            FilterEngine.renderOriginalImage(
                from: request.originalImage,
                values: request.filterValues
            )
        }).value else {
            return .failed(BackgroundFilterExportError.imageRenderFailed.localizedDescription)
        }

        let finalImage = await addWatermarkIfNeeded(to: renderedImage, filter: request.appliedFilter)

        do {
            try await saveToPhotoLibrary(image: finalImage)
            return .succeeded
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? BackgroundFilterExportError.photoLibrarySaveFailed.localizedDescription
            return .failed(message)
        }
    }

    private static func addWatermarkIfNeeded(to image: UIImage, filter: FilterDetail?) async -> UIImage {
        guard let filter else { return image }
        let thumbnailImage = await loadThumbnailImage(for: filter)
        return await MainActor.run {
            image.addingWatermark(
                filterName: filter.title,
                creatorNickname: filter.creator.nickname,
                filterThumbnail: thumbnailImage
            )
        }
    }

    private static func loadThumbnailImage(for filter: FilterDetail) async -> UIImage? {
        guard let path = filter.previewImages.first,
              let url = normalizedFeelterURL(from: path) else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private static func normalizedFeelterURL(from path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        let baseURLString = Config.baseURL.absoluteString
        let cleanedBase = baseURLString.hasSuffix("/") ? String(baseURLString.dropLast()) : baseURLString

        var urlPath = path
        if urlPath.hasPrefix("/data/") {
            urlPath = "/v1" + urlPath
        } else if !urlPath.hasPrefix("/v1/") {
            urlPath = "/v1/" + urlPath
        }

        return URL(string: cleanedBase + urlPath)
    }

    private static func saveToPhotoLibrary(image: UIImage) async throws {
        let isAuthorized = await requestPhotoLibraryAccess()
        guard isAuthorized else {
            throw BackgroundFilterExportError.photoLibraryPermissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { isSuccess, error in
                if isSuccess {
                    continuation.resume(returning: ())
                    return
                }
                continuation.resume(throwing: error ?? BackgroundFilterExportError.photoLibrarySaveFailed)
            }
        }
    }

    private static func requestPhotoLibraryAccess() async -> Bool {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if currentStatus == .authorized || currentStatus == .limited {
            return true
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                let isAllowed = status == .authorized || status == .limited
                continuation.resume(returning: isAllowed)
            }
        }
    }
}
