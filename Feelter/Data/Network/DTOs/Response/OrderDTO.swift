//
//  OrderDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import Foundation

struct OrderListResponseDTO: Decodable {
    let data: [OrderDTO]
}

struct OrderDTO: Decodable {
    let orderId: String
    let orderCode: String
    let filter: FilterDTO
    let paidAt: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderCode = "order_code"
        case filter, paidAt, createdAt, updatedAt
    }
}

extension OrderDTO {
    func toDomain() -> Order? {
        let filterDetail = filter.toDetailDomain()
        guard let paidDate = ISO8601DateFormatter().date(from: paidAt),
              let createdDate = ISO8601DateFormatter().date(from: createdAt) else {
            return nil
        }

        return Order(
            id: orderId,
            orderCode: orderCode,
            filter: filterDetail,
            paidAt: paidDate,
            createdAt: createdDate
        )
    }
}
