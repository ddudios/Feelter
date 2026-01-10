//
//  PaymentRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/10/26.
//

import Foundation

protocol PaymentRepositoryProtocol {
    func createOrder(filterId: String, price: Int) async throws -> OrderInfo
    func validatePayment(impUid: String) async throws -> PaymentValidationResult
    
    func fetchMyOrder() async throws -> [PaymentValidationResult]
    func fetchReceipt(orderCode: String) async throws -> PaymentReceipt
}
