//
//  BannerRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

protocol BannerRepositoryProtocol {
    func fetchBanners() async throws -> [Banner]
}
