//
//  FilterRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation
import Alamofire

enum FilterRouter: BaseRouter {

    // 파일 업로드
    case uploadFiles(imageData: [Data])

    // 필터 CRUD
    case createFilter(body: CreateFilterRequestDTO)
    case filterList(body: FilterListRequestDTO)
    case filter(id: String)
    case updateFilter(id: String, body: UpdateFilterRequestDTO)
    case deleteFilter(id: String)

    // 필터 좋아요
    case likeFilter(id: String, body: LikeRequestDTO)

    // 특수 조회
    case todayFilter
    case hotTrend
    case getUserFilters(userId: String, query: FilterListRequestDTO)
    case myLikedFilters(query: FilterListRequestDTO)

    // 댓글
    case createComment(filterId: String, body: CreateCommentRequestDTO)
    case updateComment(filterId: String, commentId: String, body: UpdateCommentRequestDTO)
    case deleteComment(filterId: String, commentId: String)

    var method: HTTPMethod {
        switch self {
        case .uploadFiles, .createFilter, .likeFilter, .createComment:
            return .post
        case .updateFilter, .updateComment:
            return .put
        case .deleteFilter, .deleteComment:
            return .delete
        case .filterList, .filter, .todayFilter, .hotTrend, .getUserFilters, .myLikedFilters:
            return .get
        }
    }

    var path: String {
        switch self {
        case .uploadFiles:
            return "/v1/filters/files"
        case .createFilter:
            return "/v1/filters"
        case .filterList:
            return "/v1/filters"
        case .filter(let id):
            return "/v1/filters/\(id)"
        case .updateFilter(let id, _):
            return "/v1/filters/\(id)"
        case .deleteFilter(let id):
            return "/v1/filters/\(id)"
        case .likeFilter(let id, _):
            return "/v1/filters/\(id)/like"
        case .todayFilter:
            return "/v1/filters/today-filter"
        case .hotTrend:
            return "/v1/filters/hot-trend"
        case .getUserFilters(let userId, _):
            return "/v1/filters/users/\(userId)"
        case .myLikedFilters:
            return "/v1/filters/likes/me"
        case .createComment(let filterId, _):
            return "/v1/filters/\(filterId)/comments"
        case .updateComment(let filterId, let commentId, _):
            return "/v1/filters/\(filterId)/comments/\(commentId)"
        case .deleteComment(let filterId, let commentId):
            return "/v1/filters/\(filterId)/comments/\(commentId)"
        }
    }

    var queryParameters: Encodable? {
        switch self {
        case .filterList(let body):
            return body
        case .getUserFilters(_, let query):
            return query
        case .myLikedFilters(let query):
            return query
        case .uploadFiles, .createFilter, .filter, .updateFilter, .deleteFilter, .likeFilter,
             .todayFilter, .hotTrend, .createComment, .updateComment, .deleteComment:
            return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .createFilter(let body):
            return body
        case .updateFilter(_, let body):
            return body
        case .likeFilter(_, let body):
            return body
        case .createComment(_, let body):
            return body
        case .updateComment(_, _, let body):
            return body
        case .uploadFiles, .filterList, .filter, .deleteFilter, .todayFilter, .hotTrend,
             .getUserFilters, .myLikedFilters, .deleteComment:
            return nil
        }
    }
}
