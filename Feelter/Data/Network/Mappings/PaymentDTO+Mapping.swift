//
//  PaymentDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/10/26.
//

import Foundation

extension CreateOrderResponseDTO {
    func toDomain() -> OrderInfo {
        return OrderInfo(
            orderId: self.orderId,
            orderCode: self.orderCode,
            totalPrice: self.totalPrice,
            createdAt: self.createdAt.toDate() ?? Date()
        )
    }
}

extension PaymentValidationResponseDTO {
    func toDomain() -> PaymentValidationResult {
        return PaymentValidationResult(
            paymentId: self.paymentId,
            orderCode: self.orderItem.orderCode,
            paidAt: self.orderItem.paidAt?.toDate(),
            filter: self.orderItem.filter.toDetailDomain(),
            createdAt: self.createdAt.toDate() ?? Date()
        )
    }
}

extension PaymentReceiptResponseDTO {
    func toDomain() -> PaymentReceipt {
        // Unix Timestamp 변환 로직
        let vbankDueDate: Date? = {
            guard let timestamp = self.vbankDate else { return nil }
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }()
        
        return PaymentReceipt(
            impUid: self.impUid,
            merchantUid: self.merchantUid,
            payMethod: self.payMethod,
            status: self.status,
            amount: self.amount,
            name: self.name,
            paidAt: self.paidAt?.toDate(),
            receiptUrl: self.receiptUrl,
            bankName: self.bankName,
            cardName: self.cardName,
            cardNumber: self.cardNumber,
            cardQuota: self.cardQuota,
            vbankName: self.vbankName,
            vbankNum: self.vbankNum,
            vbankHolder: self.vbankHolder,
            vbankDate: vbankDueDate
        )
    }
}
