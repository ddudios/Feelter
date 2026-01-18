//
//  FilterRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

protocol FilterRepositoryProtocol {
    func fetchFilterList(
        category: FilterCategory?,
        orderBy: FilterSortType,
        next: String?,
        limit: String?
    ) async throws -> FilterList

    func fetchFilter(id: String) async throws -> FilterDetail
    func fetchTodayFilter() async throws -> TodayFilter
    func fetchHotTrends() async throws -> [FilterSummary]
    func likeFilter(id: String, status: Bool) async throws -> Bool
    func createFilter(requestDTO: CreateFilterRequestDTO) async throws -> FilterDetail
    func updateFilter(id: String, requestDTO: UpdateFilterRequestDTO) async throws -> FilterDetail
    func deleteFilter(id: String) async throws
    func uploadFiles(_ imageData: [Data]) async throws -> [String]
}
