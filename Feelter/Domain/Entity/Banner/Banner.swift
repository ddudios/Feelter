//
//  Banner.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

struct Banner: Hashable, Identifiable {
    let id = UUID()
    let title: String
    let imageURL: String
    let linkType: BannerLinkType
    let linkPath: String
}

// 라우팅 타입
enum BannerLinkType: Hashable {
    case webView
    case unknown(String) // 나중에 새로운 타입이 추가될 대비
}
