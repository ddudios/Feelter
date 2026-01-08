//
//  BannerDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

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
