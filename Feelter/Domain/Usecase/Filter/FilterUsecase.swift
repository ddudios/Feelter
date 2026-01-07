//
//  FilterUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

protocol FilterUsecaseProtocol {
    func fetchTodayFilter() async throws -> TodayFilter
}

struct FilterUsecase: FilterUsecaseProtocol {
    
    private let repository: FilterRepositoryProtocol
    
    init(repository: FilterRepositoryProtocol) {
        self.repository = repository
    }
    
    func fetchTodayFilter() async throws -> TodayFilter {
        try await repository.fetchTodayFilter()
    }
}
