//
//  PaymentRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/10/26.
//

import Foundation

final class PaymentRepository: PaymentRepositoryProtocol {
    
    private let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }
    
    func createOrder(filterId: String, price: Int) async throws -> OrderInfo {
        let response = try await networkManager.request(PaymentRouter.createOrder(body: CreateOrderRequestDTO(filterId: filterId, totalPrice: price)), type: CreateOrderResponseDTO.self)
        
        return response.toDomain()
    }
    
    func validatePayment(impUid: String) async throws -> PaymentValidationResult {
        let response = try await networkManager.request(PaymentRouter.validatePayment(body: PaymentValidationRequestDTO(impUid: impUid)), type: PaymentValidationResponseDTO.self)
        
        return response.toDomain()
    }
    
    func fetchMyOrder() async throws -> [PaymentValidationResult] {
        let response = try await networkManager.request(PaymentRouter.fetchMyOrders, type: MyOrdersResponseDTO.self)
        
        return response.data.map { $0.toDomain() }
    }
    
    func fetchReceipt(orderCode: String) async throws -> PaymentReceipt {
        let response = try await networkManager.request(PaymentRouter.fetchReceipt(orderCode: orderCode), type: PaymentReceiptResponseDTO.self)
        
        return response.toDomain()
    }
}
