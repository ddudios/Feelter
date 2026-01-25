//
//  VideoRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation
import Alamofire

enum VideoRouter: BaseRouter {

    case videoList(next: String?, limit: Int?)
    case stream(videoId: String)
    case subtitle(url: String)
    case likeVideo(videoId: String, body: LikeRequestDTO)

    var method: HTTPMethod {
        switch self {
        case .videoList, .stream, .subtitle:
            return .get
        case .likeVideo:
            return .post
        }
    }

    var path: String {
        switch self {
        case .videoList:
            return "/v1/videos"
        case .stream(let videoId):
            return "/v1/videos/\(videoId)/stream"
        case .subtitle(let url):
            // url은 "/videos/stream/..." 형태이므로 "/v1"을 앞에 붙임
            return "/v1" + url
        case .likeVideo(let videoId, _):
            return "/v1/videos/\(videoId)/like"
        }
    }

    var queryParameters: Encodable? {
        switch self {
        case .videoList(let next, let limit):
            struct VideoListQuery: Encodable {
                let next: String?
                let limit: Int?
            }
            return VideoListQuery(next: next, limit: limit)
        case .stream, .subtitle, .likeVideo:
            return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .likeVideo(_, let body):
            return body
        case .videoList, .stream, .subtitle:
            return nil
        }
    }
}
