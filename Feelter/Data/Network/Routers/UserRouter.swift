//
//  UserRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//

import Foundation
import Alamofire

enum UserRouter: BaseRouter {

    // 인증 관련
    case validateEmail(body: EmailValidationRequestDTO)
    case join(body: JoinRequestDTO)
    case login(body: LoginRequestDTO)
    case kakaoLogin(body: KakaoLoginRequestDTO)
    case appleLogin(body: AppleLoginRequestDTO)
    case logout

    // 디바이스 토큰
    case updateDeviceToken(body: DeviceTokenUpdateRequestDTO)

    // 프로필 관련
    case otherProfile(userId: String)
    case myProfile
    case updateProfile(body: ProfileUpdateRequestDTO)
    case uploadProfileImage(imageData: Data)

    // 작가/검색
    case todayAuthor
    case searchUsers(nick: String?)

    var method: HTTPMethod {
        switch self {
        case .validateEmail, .join, .login, .kakaoLogin, .appleLogin, .logout, .uploadProfileImage:
            return .post
        case .updateDeviceToken, .updateProfile:
            return .put
        case .otherProfile, .myProfile, .todayAuthor, .searchUsers:
            return .get
        }
    }

    var path: String {
        switch self {
        case .validateEmail:
            return "/v1/users/validation/email"
        case .join:
            return "/v1/users/join"
        case .login:
            return "/v1/users/login"
        case .kakaoLogin:
            return "/v1/users/login/kakao"
        case .appleLogin:
            return "/v1/users/login/apple"
        case .logout:
            return "/v1/users/logout"
        case .updateDeviceToken:
            return "/v1/users/deviceToken"
        case .otherProfile(let userId):
            return "/v1/users/\(userId)/profile"
        case .uploadProfileImage:
            return "/v1/users/profile/image"
        case .myProfile:
            return "/v1/users/me/profile"
        case .updateProfile:
            return "/v1/users/me/profile"
        case .todayAuthor:
            return "/v1/users/today-author"
        case .searchUsers:
            return "/v1/users/search"
        }
    }

    var body: Encodable? {
        switch self {
        case .validateEmail(let body):
            return body
        case .join(let body):
            return body
        case .login(let body):
            return body
        case .kakaoLogin(let body):
            return body
        case .appleLogin(let body):
            return body
        case .updateDeviceToken(let body):
            return body
        case .updateProfile(let body):
            return body
        case .logout, .otherProfile, .myProfile, .uploadProfileImage, .todayAuthor, .searchUsers:
            return nil
        }
    }

    var queryParameters: Encodable? {
        switch self {
        case .searchUsers(let nick):
            struct SearchQuery: Encodable {
                let nick: String?
            }
            return SearchQuery(nick: nick)
        default:
            return nil
        }
    }
}
