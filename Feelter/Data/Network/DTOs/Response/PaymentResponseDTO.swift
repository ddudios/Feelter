//
//  PaymentResponseDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/10/26.
//

import Foundation

struct CreateOrderResponseDTO: Decodable {
    let orderId: String
    let orderCode: String
    let totalPrice: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderCode = "order_code"
        case totalPrice = "total_price"
        case createdAt, updatedAt
    }
}

struct MyOrdersResponseDTO: Decodable {
    let data: [PaymentValidationResponseDTO]
}

struct PaymentValidationResponseDTO: Decodable {
    let paymentId: String
    let orderItem: OrderItemDTO
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case paymentId = "payment_id"
        case orderItem = "order_item"
        case createdAt, updatedAt
    }
}

struct OrderItemDTO: Decodable {
    let orderId: String
    let orderCode: String
    let filter: FilterDTO
    let paidAt: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderCode = "order_code"
        case filter
        case paidAt, createdAt, updatedAt
    }
}

// MARK: - 결제 영수증 조회 (GET /v1/payments/{order_code})
struct PaymentReceiptResponseDTO: Decodable {
    let impUid: String
    let merchantUid: String
    let payMethod: String
    let channel: String
    let pgProvider: String
    let embPgProvider: String?
    let pgTid: String?
    let pgId: String?
    let escrow: Bool?
    let applyNum: String?
    
    // 계좌/카드 공통
    let bankCode: String?
    let bankName: String?
    
    // 카드 결제 시
    let cardCode: String?
    let cardName: String?
    let cardIssuerCode: String?
    let cardIssuerName: String?
    let cardPublisherCode: String?
    let cardPublisherName: String?
    let cardQuota: Int?
    let cardNumber: String?
    let cardType: Int?
    
    // 가상계좌 결제 시
    let vbankCode: String?
    let vbankName: String?
    let vbankNum: String?
    let vbankHolder: String?
    let vbankDate: Int?      // Unix Timestamp
    let vbankIssuedAt: Int?  // Unix Timestamp
    
    // 구매자 정보
    let name: String? // 상품명
    let amount: Int
    let currency: String
    let buyerName: String?
    let buyerEmail: String?
    let buyerTel: String?
    let buyerAddr: String?
    let buyerPostcode: String?
    let customData: String?
    let userAgent: String?
    
    let status: String
    let startedAt: String? // ISO8601
    let paidAt: String?    // ISO8601
    let receiptUrl: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case impUid = "imp_uid"
        case merchantUid = "merchant_uid"
        case payMethod = "pay_method"
        case channel
        case pgProvider = "pg_provider"
        case embPgProvider = "emb_pg_provider"
        case pgTid = "pg_tid"
        case pgId = "pg_id"
        case escrow
        case applyNum = "apply_num"
        case bankCode = "bank_code"
        case bankName = "bank_name"
        case cardCode = "card_code"
        case cardName = "card_name"
        case cardIssuerCode = "card_issuer_code"
        case cardIssuerName = "card_issuer_name"
        case cardPublisherCode = "card_publisher_code"
        case cardPublisherName = "card_publisher_name"
        case cardQuota = "card_quota"
        case cardNumber = "card_number"
        case cardType = "card_type"
        case vbankCode = "vbank_code"
        case vbankName = "vbank_name"
        case vbankNum = "vbank_num"
        case vbankHolder = "vbank_holder"
        case vbankDate = "vbank_date"
        case vbankIssuedAt = "vbank_issued_at"
        case name, amount, currency
        case buyerName = "buyer_name"
        case buyerEmail = "buyer_email"
        case buyerTel = "buyer_tel"
        case buyerAddr = "buyer_addr"
        case buyerPostcode = "buyer_postcode"
        case customData = "custom_data"
        case userAgent = "user_agent"
        case status, startedAt, paidAt
        case receiptUrl = "receipt_url"
        case createdAt, updatedAt
    }
}
