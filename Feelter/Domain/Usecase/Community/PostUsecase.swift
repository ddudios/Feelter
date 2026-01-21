//
//  PostUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/21/26.
//

import Foundation

protocol PostUsecaseProtocol {
    func fetchGeolocationPosts(
        category: String?,
        longitude: Double?,
        latitude: Double?,
        maxDistance: Int?,
        limit: Int?,
        next: String?,
        orderBy: PostSortType
    ) async throws -> (posts: [PostSummary], nextCursor: String?)
    func searchPosts(title: String?) async throws -> [PostSummary]
    func fetchPostDetail(postId: String) async throws -> PostDetail
    func createPost(input: CreatePostInput) async throws -> PostDetail
    func updatePost(input: UpdatePostInput) async throws -> PostDetail
    func deletePost(postId: String) async throws

    // Comments
    func createComment(postId: String, content: String) async throws -> Comment
    func updateComment(postId: String, commentId: String, content: String) async throws -> Comment
    func deleteComment(postId: String, commentId: String) async throws
}

struct CreatePostInput {
    let category: String
    let title: String
    let content: String
    let latitude: Double
    let longitude: Double
    let files: [UploadFile]
}

struct UpdatePostInput {
    let postId: String
    let category: String
    let title: String
    let content: String
    let latitude: Double
    let longitude: Double
    let newFiles: [UploadFile]
    let existingFilePaths: [String]
}

struct PostUsecase: PostUsecaseProtocol {

    private let repository: CommunityRepositoryProtocol

    init(repository: CommunityRepositoryProtocol) {
        self.repository = repository
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
        try await repository.fetchGeolocationPosts(
            category: category,
            longitude: longitude,
            latitude: latitude,
            maxDistance: maxDistance,
            limit: limit,
            next: next,
            orderBy: orderBy
        )
    }

    func searchPosts(title: String?) async throws -> [PostSummary] {
        try await repository.searchPosts(title: title)
    }

    func fetchPostDetail(postId: String) async throws -> PostDetail {
        try await repository.fetchPostDetail(postId: postId)
    }

    func createPost(input: CreatePostInput) async throws -> PostDetail {
        print("🔵 [PostUsecase] createPost 시작")
        print("   카테고리: \(input.category)")
        print("   제목: \(input.title)")
        print("   파일 개수: \(input.files.count)")

        let fileURLs: [String]?
        if input.files.isEmpty {
            print("   📄 첨부 파일 없음")
            fileURLs = nil
        } else {
            print("   📤 파일 업로드 시작...")
            do {
                fileURLs = try await repository.uploadFiles(input.files)
                print("   ✅ 파일 업로드 완료: \(fileURLs ?? [])")
            } catch {
                print("   ❌ 파일 업로드 실패: \(error)")
                throw error
            }
        }

        let requestDTO = CreatePostRequestDTO(
            category: input.category,
            title: input.title,
            content: input.content,
            latitude: input.latitude,
            longitude: input.longitude,
            files: fileURLs
        )

        print("   📡 게시글 생성 요청 전송...")
        do {
            let result = try await repository.createPost(requestDTO: requestDTO)
            print("   ✅ 게시글 생성 완료: \(result.id)")
            return result
        } catch {
            print("   ❌ 게시글 생성 실패: \(error)")
            throw error
        }
    }

    func updatePost(input: UpdatePostInput) async throws -> PostDetail {
        var fileURLs = input.existingFilePaths
        if !input.newFiles.isEmpty {
            let uploaded = try await repository.uploadFiles(input.newFiles)
            fileURLs.append(contentsOf: uploaded)
        }

        let requestDTO = UpdatePostRequestDTO(
            category: input.category,
            title: input.title,
            content: input.content,
            latitude: input.latitude,
            longitude: input.longitude,
            files: fileURLs
        )

        return try await repository.updatePost(postId: input.postId, requestDTO: requestDTO)
    }

    func deletePost(postId: String) async throws {
        try await repository.deletePost(postId: postId)
    }

    func createComment(postId: String, content: String) async throws -> Comment {
        try await repository.createComment(postId: postId, content: content)
    }

    func updateComment(postId: String, commentId: String, content: String) async throws -> Comment {
        try await repository.updateComment(postId: postId, commentId: commentId, content: content)
    }

    func deleteComment(postId: String, commentId: String) async throws {
        try await repository.deleteComment(postId: postId, commentId: commentId)
    }
}
