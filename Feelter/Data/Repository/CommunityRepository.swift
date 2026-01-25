//
//  CommunityRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation
import UIKit
import AVFoundation

final class CommunityRepository: CommunityRepositoryProtocol {

    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func fetchGeolocationPosts(
        category: String?,
        longitude: Double?,
        latitude: Double?,
        maxDistance: Int?,
        limit: Int?,
        next: String?,
        orderBy: PostSortType
    ) async throws -> (posts: [PostSummary], nextCursor: String?) {
        let requestDTO = PostListRequestDTO(
            category: category,
            longitude: longitude.map { String(format: "%.6f", $0) },
            latitude: latitude.map { String(format: "%.6f", $0) },
            maxDistance: maxDistance.map { String($0) },
            limit: limit,
            next: next,
            orderBy: orderBy
        )

        let response = try await networkManager.request(
            PostRouter.geolocationPosts(query: requestDTO),
            type: PostListResponseDTO.self
        )

        return response.toDomain()
    }

    func searchPosts(title: String?) async throws -> [PostSummary] {
        let requestDTO = PostSearchRequestDTO(title: title)

        let response = try await networkManager.request(
            PostRouter.searchPosts(query: requestDTO),
            type: PostSearchResponseDTO.self
        )

        return response.toDomain()
    }

    func fetchPostDetail(postId: String) async throws -> PostDetail {
        let response = try await networkManager.request(
            PostRouter.post(id: postId),
            type: PostDTO.self
        )

        return response.toDetailDomain()
    }

    func createPost(requestDTO: CreatePostRequestDTO) async throws -> PostDetail {
        let response = try await networkManager.request(
            PostRouter.createPost(body: requestDTO),
            type: PostDTO.self
        )

        return response.toDetailDomain()
    }

    func updatePost(postId: String, requestDTO: UpdatePostRequestDTO) async throws -> PostDetail {
        let response = try await networkManager.request(
            PostRouter.updatePost(id: postId, body: requestDTO),
            type: PostDTO.self
        )

        return response.toDetailDomain()
    }

    func deletePost(postId: String) async throws {
        try await networkManager.requestWithEmptyResponse(
            PostRouter.deletePost(id: postId)
        )
    }

    func likePost(postId: String, status: Bool) async throws -> Bool {
        // Router 호출
        let router = PostRouter.likePost(
            id: postId,
            body: LikeRequestDTO(likeStatus: status)
        )

        // DTO 받기
        let response = try await networkManager.request(router, type: LikeResponseDTO.self)

        // DTO -> Domain(Bool) 변환
        return response.likeStatus
    }

    func uploadFiles(_ files: [UploadFile]) async throws -> [String] {
        do {
            var allData: [Data] = []
            var allExtensions: [String] = []

            for file in files {
                if file.isVideo && file.normalizedFileExtension != "mp4" {
                    // 동영상이고 mp4가 아닌 경우: mp4로 변환 후 업로드
                    do {
                        let mp4Data = try await convertVideoToMP4(from: file.data)
                        allData.append(mp4Data)
                        allExtensions.append("mp4")  // mov → mp4
                    } catch {
                        continue
                    }
                } else {
                    // 이미 mp4이거나 이미지인 경우: 그대로 추가
                    allData.append(file.data)
                    allExtensions.append(file.normalizedFileExtension)
                }
            }

            guard !allData.isEmpty else {
                throw FileUploadError.noFiles
            }

            // 모든 파일을 한 번에 업로드
            let uploadedPaths = try await networkManager.uploadFiles(
                allData,
                fileExtensions: allExtensions,
                config: .post,
                endpoint: PostRouter.uploadFiles(imageData: allData)
            )

            return uploadedPaths
        } catch {
            throw error
        }
    }

    /// 동영상 파일 Data를 mp4로 변환
    /// - Parameter videoData: 원본 동영상 Data (mov, m4v 등)
    /// - Returns: mp4로 변환된 Data
    private func convertVideoToMP4(from videoData: Data) async throws -> Data {
        // 1. Data를 임시 파일로 저장 (AVAsset은 URL이 필요함)
        let tempDirectory = FileManager.default.temporaryDirectory
        let inputURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mp4")

        try videoData.write(to: inputURL)

        defer {
            // 작업 완료 후 임시 파일들 삭제
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        // 2. AVAsset으로 동영상 로드
        let asset = AVAsset(url: inputURL)

        // 3. Export Session 생성 (고품질 프리셋)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw FileUploadError.noFiles
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4  // ✅ mp4로 변환
        exportSession.shouldOptimizeForNetworkUse = true

        // 4. 변환 시작 (async/await)
        await exportSession.export()

        // 5. 변환 결과 확인
        guard exportSession.status == .completed else {
            throw FileUploadError.noFiles
        }

        // 6. 변환된 mp4 파일을 Data로 읽기
        let mp4Data = try Data(contentsOf: outputURL)

        return mp4Data
    }

    /// 동영상 파일 Data로부터 첫 프레임 썸네일 생성
    /// - Parameter videoData: 동영상 파일 Data
    /// - Returns: 썸네일 JPEG Data
    private func generateVideoThumbnail(from videoData: Data) throws -> Data {
        // 1. Data를 임시 파일로 저장 (AVAsset은 URL이 필요함)
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mov")

        try videoData.write(to: tempFileURL)

        defer {
            // 2. 작업 완료 후 임시 파일 삭제
            try? FileManager.default.removeItem(at: tempFileURL)
        }

        // 3. AVAsset으로 동영상 로드
        let asset = AVAsset(url: tempFileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        // 4. 첫 프레임 추출 (0초)
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        let imageRef = try generator.copyCGImage(at: time, actualTime: nil)
        let thumbnailImage = UIImage(cgImage: imageRef)

        // 5. JPEG Data로 변환 (0.8 품질)
        guard let jpegData = thumbnailImage.jpegData(compressionQuality: 0.8) else {
            throw FileUploadError.noFiles  // 적절한 에러로 변경 가능
        }

        return jpegData
    }

    func createComment(postId: String, content: String) async throws -> Comment {
        let requestDTO = CreateCommentRequestDTO(parentCommentId: nil, content: content)
        let response = try await networkManager.request(
            PostRouter.createComment(postId: postId, body: requestDTO),
            type: CommentDTO.self
        )
        return response.toDomain()
    }

    func updateComment(postId: String, commentId: String, content: String) async throws -> Comment {
        let requestDTO = UpdateCommentRequestDTO(content: content)
        let response = try await networkManager.request(
            PostRouter.updateComment(postId: postId, commentId: commentId, body: requestDTO),
            type: CommentDTO.self
        )
        return response.toDomain()
    }

    func deleteComment(postId: String, commentId: String) async throws {
        try await networkManager.requestWithEmptyResponse(
            PostRouter.deleteComment(postId: postId, commentId: commentId)
        )
    }
}
