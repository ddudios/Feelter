//
//  BannerResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

struct BannerResponseDTO: Decodable {
    let data: [BannerDTO]
}

// 배너 아이템
struct BannerDTO: Decodable {
    let name: String
    let imageUrl: String
    let payload: BannerPayloadDTO
}

// 페이로드 (이동 정보)
struct BannerPayloadDTO: Decodable {
    let type: String
    let value: String
}

extension BannerDTO {
    func toDomain() -> Banner {
        return Banner(
            title: name,
            // 이미지 경로 결합
            imageURL: imageUrl,
            linkType: convertLinkType(type: payload.type),
            linkPath: payload.value
        )
    }
    
    // String -> Enum 변환 헬퍼
    private func convertLinkType(type: String) -> BannerLinkType {
        switch type.uppercased() {
        case "WEBVIEW": return .webView
        default: return .unknown(type)
        }
    }
}
