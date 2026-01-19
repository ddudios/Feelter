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
        let response = try await networkManager.request(
            OrderRouter.fetchOrders,
            type: OrderListResponseDTO.self
        )

        return response.data.compactMap { $0.toDomain() }
    }
}
