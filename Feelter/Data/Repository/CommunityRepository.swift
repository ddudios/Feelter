//
//  CommunityRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation

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
        print("📤 [CommunityRepository] 파일 업로드 시작 - 파일 개수: \(files.count)")

        let dataList = files.map { $0.data }

        for (index, file) in files.enumerated() {
            let sizeInMB = Double(file.data.count) / (1024 * 1024)
            print("   📄 [\(index)] 확장자: \(file.normalizedFileExtension), 크기: \(String(format: "%.2f", sizeInMB))MB")
        }

        do {
            // ✅ 이미지만 먼저 업로드 (서버가 비디오를 거부하는 것 같음)
            let imageFiles = files.filter { !$0.isVideo }
            let videoFiles = files.filter { $0.isVideo }

            var uploadedPaths: [String] = []

            // 이미지 업로드
            if !imageFiles.isEmpty {
                let imagePaths = try await networkManager.uploadFiles(
                    imageFiles.map { $0.data },
                    fileExtensions: imageFiles.map { $0.normalizedFileExtension },
                    config: .post,
                    endpoint: PostRouter.uploadFiles(imageData: imageFiles.map { $0.data })
                )
                uploadedPaths.append(contentsOf: imagePaths)
                print("✅ [CommunityRepository] 이미지 업로드 성공: \(imagePaths)")
            }

            // 비디오는 별도 처리 시도
            if !videoFiles.isEmpty {
                print("⚠️ [CommunityRepository] 비디오 파일 감지 - 서버 지원 확인 필요")
                // 비디오도 동일한 방식으로 시도
                do {
                    let videoPaths = try await networkManager.uploadFiles(
                        videoFiles.map { $0.data },
                        fileExtensions: videoFiles.map { $0.normalizedFileExtension },
                        config: .post,
                        endpoint: PostRouter.uploadFiles(imageData: videoFiles.map { $0.data })
                    )
                    uploadedPaths.append(contentsOf: videoPaths)
                    print("✅ [CommunityRepository] 비디오 업로드 성공: \(videoPaths)")
                } catch {
                    print("❌ [CommunityRepository] 비디오 업로드 실패 - 이미지만 사용: \(error)")
                    // 비디오 업로드 실패 시 이미지만 사용
                }
            }

            guard !uploadedPaths.isEmpty else {
                throw FileUploadError.noFiles
            }

            print("✅ [CommunityRepository] 전체 업로드 완료: \(uploadedPaths)")
            return uploadedPaths
        } catch {
            print("❌ [CommunityRepository] 파일 업로드 실패 - 에러: \(error)")
            throw error
        }
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
