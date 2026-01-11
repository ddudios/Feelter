//
//  PaymentRouter.swift
//  Feelter
//
//  Created by Suji Jang on 1/10/26.
//

import Foundation
import Alamofire

enum PaymentRouter: BaseRouter {
    
    case createOrder(body: CreateOrderRequestDTO)
    case validatePayment(body: PaymentValidationRequestDTO)
    
    case fetchMyOrders
    case fetchReceipt(orderCode: String)
    
    var method: HTTPMethod {
        switch self {
        case .createOrder, .validatePayment: .post
        case .fetchMyOrders, .fetchReceipt: .get
        }
    }
    
    var path: String {
        switch self {
        case .createOrder, .fetchMyOrders: "/v1/orders"
        case .validatePayment: "/v1/payments/validation"
        case let .fetchReceipt(orderCode): "/v1/payments/\(orderCode)"
        }
    }
    
    var body: Encodable? {
        switch self {
        case let .createOrder(body): body
        case let .validatePayment(body): body
        case .fetchMyOrders, .fetchReceipt: nil
        }
    }

    // 타임아웃
    var timeoutInterval: TimeInterval {
        switch self {
        case .createOrder:
            return 300 // 주문 생성
        case .validatePayment:
            return 300 // 결제 검증 (PG사 통신 고려)
        case .fetchMyOrders, .fetchReceipt:
            return 30 // 기본 타임아웃
        }
    }
}
