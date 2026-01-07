//
//  Community.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import Foundation
import Alamofire

enum CommunityRouter: BaseRouter {
    
    case likePost(postId: String, status: Bool)
    
    var method: HTTPMethod {
        switch self {
        case .likePost:
            return .post
        }
    }
    
    var path: String {
        switch self {
        case let .likePost(postId, _): "/v1/posts/\(postId)/like"
        }
    }
    
    var body: Encodable? {
        switch self {
        case let .likePost(_, status):
            return LikeRequestDTO(likeStatus: status)
        }
    }
}
