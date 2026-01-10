//
//  PaymentDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/10/26.
//

import Foundation

// MARK: - 1. 주문 생성 (POST /v1/orders)
struct CreateOrderRequestDTO: Encodable {
    let filterId: String
    let totalPrice: Int
    
    enum CodingKeys: String, CodingKey {
        case filterId = "filter_id"
        case totalPrice = "total_price"
    }
}

// MARK: - 2. 결제 검증 (POST /v1/payments/validation)
struct PaymentValidationRequestDTO: Encodable {
    let impUid: String
    
    enum CodingKeys: String, CodingKey {
        case impUid = "imp_uid"
    }
}
