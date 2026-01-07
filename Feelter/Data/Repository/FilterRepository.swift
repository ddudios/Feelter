//
//  FilterRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

final class FilterRepository: FilterRepositoryProtocol {
    
    private let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }
    
    func fetchTodayFilter() async throws -> TodayFilter {
        let response = try await networkManager.request(FilterRouter.todayFilter, type: TodayFilterResponseDTO.self)
        
        return response.toDomain()
    }
}
