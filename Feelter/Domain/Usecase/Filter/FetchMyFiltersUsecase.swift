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
        print("🎨 [FetchMyFiltersUsecase] 필터 조회 시작")

        async let myFiltersTask = fetchAllMyFilters(userId: userId)
        async let purchasedFiltersTask = fetchPurchasedFilters()

        let (myFilters, purchasedFilters) = try await (myFiltersTask, purchasedFiltersTask)

        print("🎨 [FetchMyFiltersUsecase] 내가 만든 필터: \(myFilters.count)개")
        print("🎨 [FetchMyFiltersUsecase] 구매한 필터: \(purchasedFilters.count)개")

        // 중복 제거 (filter_id 기준)
        var filterDict: [String: FilterDetail] = [:]
        myFilters.forEach { filterDict[$0.id] = $0 }
        purchasedFilters.forEach { filterDict[$0.id] = $0 }

        let result = Array(filterDict.values)
        print("🎨 [FetchMyFiltersUsecase] 최종 필터 개수 (중복 제거 후): \(result.count)개")

        return result
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

        // FilterSummary → FilterDetail 변환 (삭제된 필터는 제외)
        return await withTaskGroup(of: FilterDetail?.self) { group in
            for filter in filters {
                group.addTask {
                    do {
                        return try await self.filterRepository.fetchFilter(id: filter.id)
                    } catch {
                        print("⚠️ [FetchMyFiltersUsecase] 필터 상세 조회 실패 (삭제된 필터일 수 있음): \(filter.title) (ID: \(filter.id))")
                        return nil
                    }
                }
            }

            var details: [FilterDetail] = []
            for await detail in group {
                if let detail = detail {
                    details.append(detail)
                }
            }
            return details
        }
    }

    /// 결제한 필터 조회
    private func fetchPurchasedFilters() async throws -> [FilterDetail] {
        do {
            let orders = try await orderRepository.fetchOrders()
            print("🎨 [FetchMyFiltersUsecase] Order API 응답: \(orders.count)개")

            let filters = orders.map { $0.filter }
            filters.enumerated().forEach { index, filter in
                print("   [구매한 필터 \(index)] \(filter.title) (ID: \(filter.id))")
            }

            return filters
        } catch {
            print("❌ [FetchMyFiltersUsecase] 구매한 필터 조회 실패: \(error.localizedDescription)")
            // 구매한 필터 조회 실패 시 빈 배열 반환 (내가 만든 필터는 계속 표시)
            return []
        }
    }
}
