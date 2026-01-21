//
//  PostRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation
import Alamofire

enum PostRouter: BaseRouter {

    // 파일 업로드
    case uploadFiles(imageData: [Data])

    // 게시글 CRUD
    case createPost(body: CreatePostRequestDTO)
    case geolocationPosts(query: PostListRequestDTO)
    case searchPosts(query: PostSearchRequestDTO)
    case post(id: String)
    case updatePost(id: String, body: UpdatePostRequestDTO)
    case deletePost(id: String)

    // 게시글 좋아요
    case likePost(id: String, body: LikeRequestDTO)

    // 특수 조회
    case getUserPosts(userId: String, query: PostListRequestDTO)
    case myLikedPosts(query: PostListRequestDTO)

    // 댓글
    case createComment(postId: String, body: CreateCommentRequestDTO)
    case updateComment(postId: String, commentId: String, body: UpdateCommentRequestDTO)
    case deleteComment(postId: String, commentId: String)

    var method: HTTPMethod {
        switch self {
        case .uploadFiles, .createPost, .likePost, .createComment:
            return .post
        case .updatePost, .updateComment:
            return .put
        case .deletePost, .deleteComment:
            return .delete
        case .geolocationPosts, .searchPosts, .post, .getUserPosts, .myLikedPosts:
            return .get
        }
    }

    var path: String {
        switch self {
        case .uploadFiles:
            return "/v1/posts/files"
        case .createPost:
            return "/v1/posts"
        case .geolocationPosts:
            return "/v1/posts/geolocation"
        case .searchPosts:
            return "/v1/posts/search"
        case .post(let id):
            return "/v1/posts/\(id)"
        case .updatePost(let id, _):
            return "/v1/posts/\(id)"
        case .deletePost(let id):
            return "/v1/posts/\(id)"
        case .likePost(let id, _):
            return "/v1/posts/\(id)/like"
        case .getUserPosts(let userId, _):
            return "/v1/posts/users/\(userId)"
        case .myLikedPosts:
            return "/v1/posts/likes/me"
        case .createComment(let postId, _):
            return "/v1/posts/\(postId)/comments"
        case .updateComment(let postId, let commentId, _):
            return "/v1/posts/\(postId)/comments/\(commentId)"
        case .deleteComment(let postId, let commentId):
            return "/v1/posts/\(postId)/comments/\(commentId)"
        }
    }

    var queryParameters: Encodable? {
        switch self {
        case .geolocationPosts(let query):
            return query
        case .searchPosts(let query):
            return query
        case .getUserPosts(_, let query):
            return query
        case .myLikedPosts(let query):
            return query
        case .uploadFiles, .createPost, .post, .updatePost, .deletePost, .likePost,
             .createComment, .updateComment, .deleteComment:
            return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .createPost(let body):
            return body
        case .updatePost(_, let body):
            return body
        case .likePost(_, let body):
            return body
        case .createComment(_, let body):
            return body
        case .updateComment(_, _, let body):
            return body
        case .uploadFiles, .geolocationPosts, .searchPosts, .post, .deletePost,
             .getUserPosts, .myLikedPosts, .deleteComment:
            return nil
        }
    }

    var headers: HTTPHeaders {
        switch self {
        case .uploadFiles:
            // multipart 업로드는 Content-Type을 Alamofire가 자동으로 설정
            // Authorization 헤더는 유지 (APISession에서 자동 추가됨)
            var customHeaders = defaultHeaders
            customHeaders.remove(name: "Content-Type")
            return customHeaders
        default:
            return defaultHeaders
        }
    }
}
