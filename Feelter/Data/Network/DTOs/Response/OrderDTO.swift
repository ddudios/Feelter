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

        // ISO8601DateFormatter 설정 (밀리초 포함 형식 지원)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let paidDate = formatter.date(from: paidAt),
              let createdDate = formatter.date(from: createdAt) else {
            print("⚠️ [OrderDTO] 날짜 파싱 실패 - paidAt: \(paidAt), createdAt: \(createdAt)")
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
