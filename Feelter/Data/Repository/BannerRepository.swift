//
//  BannerRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

final class BannerRepository: BannerRepositoryProtocol {
    
    private let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }
    
    func fetchBanners() async throws -> [Banner] {
        let response = try await networkManager.request(BannerRouter.fetchBanners, type: BannerResponseDTO.self)
        
        return response.data.map { $0.toDomain() }
    }
}
