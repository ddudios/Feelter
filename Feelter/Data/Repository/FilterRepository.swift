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

    func likeFilter(id: String, status: Bool) async throws -> Bool {
        let response = try await networkManager.request(
            FilterRouter.likeFilter(id: id, body: LikeRequestDTO(likeStatus: status)),
            type: LikeResponseDTO.self
        )
        return response.likeStatus
    }
}
