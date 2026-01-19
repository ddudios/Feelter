//
//  FetchMyFiltersUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import Foundation

/// 내가 만든 필터 + 결제한 필터를 조회하는 Usecase
final class FetchMyFiltersUsecase {

    private let filterRepository: FilterRepositoryProtocol
    private let orderRepository: OrderRepositoryProtocol

    init(
        filterRepository: FilterRepositoryProtocol,
        orderRepository: OrderRepositoryProtocol
    ) {
        self.filterRepository = filterRepository
        self.orderRepository = orderRepository
    }

    /// 내가 만든 필터 + 결제한 필터를 모두 조회
    /// - Parameter userId: 현재 사용자 ID
    /// - Returns: FilterDetail 배열
    func execute(userId: String) async throws -> [FilterDetail] {
        async let myFiltersTask = fetchAllMyFilters(userId: userId)
        async let purchasedFiltersTask = fetchPurchasedFilters()

        let (myFilters, purchasedFilters) = try await (myFiltersTask, purchasedFiltersTask)

        // 중복 제거 (filter_id 기준)
        var filterDict: [String: FilterDetail] = [:]
        myFilters.forEach { filterDict[$0.id] = $0 }
        purchasedFilters.forEach { filterDict[$0.id] = $0 }

        return Array(filterDict.values)
    }

    // MARK: - Private Methods

    /// 내가 만든 필터를 페이지네이션으로 모두 가져오기
    private func fetchAllMyFilters(userId: String) async throws -> [FilterDetail] {
        var filters: [FilterSummary] = []
        var nextCursor: String?
        var iterationCount = 0
        let maxIterations = 20

        repeat {
            iterationCount += 1
            if iterationCount > maxIterations { break }

            let result = try await filterRepository.fetchUserFilters(
                userId: userId,
                next: nextCursor,
                limit: "10"
            )

            filters.append(contentsOf: result.filters)

            if let cursor = result.nextCursor,
               !cursor.isEmpty,
               cursor != "0" {
                nextCursor = cursor
            } else {
                break
            }
        } while true

        // FilterSummary → FilterDetail 변환
        return try await withThrowingTaskGroup(of: FilterDetail.self) { group in
            for filter in filters {
                group.addTask {
                    try await self.filterRepository.fetchFilter(id: filter.id)
                }
            }

            var details: [FilterDetail] = []
            for try await detail in group {
                details.append(detail)
            }
            return details
        }
    }

    /// 결제한 필터 조회
    private func fetchPurchasedFilters() async throws -> [FilterDetail] {
        let orders = try await orderRepository.fetchOrders()
        return orders.map { $0.filter }
    }
}
