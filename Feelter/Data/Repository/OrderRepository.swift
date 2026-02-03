//
//  OrderRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import Foundation

final class OrderRepository: OrderRepositoryProtocol {

    private let networkManager: NetworkManagerProtocol

    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    func fetchOrders() async throws -> [Order] {
        print("📦 [OrderRepository] GET /v1/orders 요청 시작")

        let response = try await networkManager.request(
            OrderRouter.fetchOrders,
            type: OrderListResponseDTO.self
        )

        print("📦 [OrderRepository] 응답 받음 - 주문 개수: \(response.data.count)개")

        let orders = response.data.compactMap { $0.toDomain() }
        print("📦 [OrderRepository] 도메인 변환 완료 - 유효한 주문: \(orders.count)개")

        if orders.count < response.data.count {
            let failedCount = response.data.count - orders.count
            print("⚠️ [OrderRepository] \(failedCount)개의 주문이 도메인 변환 실패 (날짜 파싱 오류 가능성)")
        }

        return orders
    }
}
