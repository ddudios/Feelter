//
//  Payment.swift
//  Feelter
//
//  Created by Suji Jang on 1/10/26.
//

import Foundation

// MARK: - 주문 생성 결과
struct OrderInfo {
    let orderId: String
    let orderCode: String
    let totalPrice: Int
    let createdAt: Date
}

// MARK: - 결제 검증 결과
struct PaymentValidationResult {
    let paymentId: String
    let orderCode: String
    let paidAt: Date?
    let filter: FilterDetail
    let createdAt: Date
}

// MARK: - 영수증 상세
struct PaymentReceipt {
    let impUid: String
    let merchantUid: String
    let payMethod: String
    let status: String
    let amount: Int
    let name: String? // 상품명
    
    let paidAt: Date?
    let receiptUrl: String?
    
    // 카드 정보
    let bankName: String?
    let cardName: String?
    let cardNumber: String?
    let cardQuota: Int?
    
    // 가상계좌 정보
    let vbankName: String?
    let vbankNum: String?
    let vbankHolder: String?
    let vbankDate: Date? // 입금기한
}
