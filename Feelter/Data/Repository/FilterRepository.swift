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

    func fetchFilterList(
        category: FilterCategory?,
        orderBy: FilterSortType,
        next: String?,
        limit: String?
    ) async throws -> FilterList {
        let requestDTO = FilterListRequestDTO(
            next: next,
            limit: limit,
            category: category?.rawValue,
            orderBy: orderBy
        )

        let response = try await networkManager.request(
            FilterRouter.filterList(body: requestDTO),
            type: FilterListResponseDTO.self
        )

        return FilterList(
            filters: response.data.map { $0.toSummaryDomain() },
            nextCursor: response.nextCursor
        )
    }

    func fetchUserFilters(
        userId: String,
        next: String?,
        limit: String?
    ) async throws -> FilterList {
        let requestDTO = FilterListRequestDTO(
            next: next,
            limit: limit,
            category: nil,
            orderBy: nil
        )

        let response = try await networkManager.request(
            FilterRouter.getUserFilters(userId: userId, query: requestDTO),
            type: FilterListResponseDTO.self
        )

        return FilterList(
            filters: response.data.map { $0.toSummaryDomain() },
            nextCursor: response.nextCursor
        )
    }

    func fetchFilter(id: String) async throws -> FilterDetail {
        let response = try await networkManager.request(
            FilterRouter.filter(id: id),
            type: FilterDTO.self
        )

        return response.toDetailDomain()
    }

    func fetchTodayFilter() async throws -> TodayFilter {
        let response = try await networkManager.request(
            FilterRouter.todayFilter,
            type: TodayFilterResponseDTO.self
        )

        return response.toDomain()
    }

    func fetchHotTrends() async throws -> [FilterSummary] {
        let response = try await networkManager.request(
            FilterRouter.hotTrend,
            type: FilterListResponseDTO.self
        )

        return response.data.map { $0.toSummaryDomain() }
    }

    func likeFilter(id: String, status: Bool) async throws -> Bool {
        let response = try await networkManager.request(
            FilterRouter.likeFilter(id: id, body: LikeRequestDTO(likeStatus: status)),
            type: LikeResponseDTO.self
        )
        return response.likeStatus
    }

    func createFilter(requestDTO: CreateFilterRequestDTO) async throws -> FilterDetail {
        let response = try await networkManager.request(
            FilterRouter.createFilter(body: requestDTO),
            type: FilterDTO.self
        )

        return response.toDetailDomain()
    }

    func updateFilter(id: String, requestDTO: UpdateFilterRequestDTO) async throws -> FilterDetail {
        let response = try await networkManager.request(
            FilterRouter.updateFilter(id: id, body: requestDTO),
            type: FilterDTO.self
        )

        return response.toDetailDomain()
    }

    func deleteFilter(id: String) async throws {
        try await networkManager.requestWithEmptyResponse(
            FilterRouter.deleteFilter(id: id)
        )
    }

    func uploadFiles(_ imageData: [Data]) async throws -> [String] {
        return try await networkManager.uploadFiles(
            imageData,
            config: .filter,  // ✅ 필터 설정 (jpg, png, jpeg / 2MB / 2개)
            endpoint: FilterRouter.uploadFiles(imageData: imageData)
        )
    }
}
