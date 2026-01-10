//
//  PaymentUsecase.swift
//  Feelter
//
//  Created by Suji Jang on 1/10/26.
//

import Foundation

protocol PaymentUsecaseProtocol {
    func createOrder(filterId: String, price: Int) async throws -> OrderInfo
    func validatePayment(impUid: String) async throws -> PaymentValidationResult
    
    func fetchMyOrder() async throws -> [PaymentValidationResult]
    func fetchReceipt(orderCode: String) async throws -> PaymentReceipt
}


struct PaymentUsecase: PaymentUsecaseProtocol {
    private let repository: PaymentRepositoryProtocol
    init(repository: PaymentRepositoryProtocol) {
        self.repository = repository
    }
    
    func createOrder(filterId: String, price: Int) async throws -> OrderInfo {
        try await repository.createOrder(filterId: filterId, price: price)
    }
    
    func validatePayment(impUid: String) async throws -> PaymentValidationResult {
        try await repository.validatePayment(impUid: impUid)
    }
    
    func fetchMyOrder() async throws -> [PaymentValidationResult] {
        try await repository.fetchMyOrder()
    }
    
    func fetchReceipt(orderCode: String) async throws -> PaymentReceipt {
        try await repository.fetchReceipt(orderCode: orderCode)
    }
}
