//
//  FilterUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

protocol FilterUsecaseProtocol {
    func fetchFilterList(
        category: FilterCategory?,
        orderBy: FilterSortType,
        next: String?,
        limit: String?
    ) async throws -> FilterList

    func fetchUserFilters(
        userId: String,
        next: String?,
        limit: String?
    ) async throws -> FilterList

    func fetchFilter(id: String) async throws -> FilterDetail
    func fetchTodayFilter() async throws -> TodayFilter
    func fetchHotTrends() async throws -> [FilterSummary]
    func likeFilter(id: String, status: Bool) async throws -> Bool

    // 필터 생성
    func uploadFiles(_ imageData: [Data]) async throws -> [String]
    func createFilter(requestDTO: CreateFilterRequestDTO) async throws -> FilterDetail
}

struct FilterUsecase: FilterUsecaseProtocol {

    private let repository: FilterRepositoryProtocol

    init(repository: FilterRepositoryProtocol) {
        self.repository = repository
    }

    func fetchFilterList(
        category: FilterCategory?,
        orderBy: FilterSortType,
        next: String?,
        limit: String?
    ) async throws -> FilterList {
        try await repository.fetchFilterList(
            category: category,
            orderBy: orderBy,
            next: next,
            limit: limit
        )
    }

    func fetchUserFilters(
        userId: String,
        next: String?,
        limit: String?
    ) async throws -> FilterList {
        try await repository.fetchUserFilters(
            userId: userId,
            next: next,
            limit: limit
        )
    }

    func fetchFilter(id: String) async throws -> FilterDetail {
        try await repository.fetchFilter(id: id)
    }

    func fetchTodayFilter() async throws -> TodayFilter {
        try await repository.fetchTodayFilter()
    }

    func fetchHotTrends() async throws -> [FilterSummary] {
        try await repository.fetchHotTrends()
    }

    func likeFilter(id: String, status: Bool) async throws -> Bool {
        try await repository.likeFilter(id: id, status: status)
    }

    func uploadFiles(_ imageData: [Data]) async throws -> [String] {
        try await repository.uploadFiles(imageData)
    }

    func createFilter(requestDTO: CreateFilterRequestDTO) async throws -> FilterDetail {
        try await repository.createFilter(requestDTO: requestDTO)
    }
}
