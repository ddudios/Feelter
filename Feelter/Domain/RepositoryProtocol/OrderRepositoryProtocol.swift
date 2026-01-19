//
//  OrderRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import Foundation

protocol OrderRepositoryProtocol {
    /// 결제 완료된 주문 내역 조회
    func fetchOrders() async throws -> [Order]
}
