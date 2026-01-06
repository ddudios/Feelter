//
//  BannerUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

protocol BannerUsecaseProtocol {
    func fetchBanners() async throws -> [Banner]
}

struct BannerUsecase: BannerUsecaseProtocol {
    
    private let repository: BannerRepositoryProtocol
    
    init(repository: BannerRepositoryProtocol) {
        self.repository = repository
    }
    
    func fetchBanners() async throws -> [Banner] {
        try await repository.fetchBanners()
    }
}
