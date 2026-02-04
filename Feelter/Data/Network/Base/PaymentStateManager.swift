//
//  PaymentStateManager.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

/// 결제 진행 상태를 추적하고 복구하는 매니저
/// 앱 종료/크래시 시에도 결제 상태를 유지하여 복구할 수 있도록 함
final class PaymentStateManager {

    static let shared = PaymentStateManager()

    private init() {}

    // MARK: - Constants
    private enum Keys {
        static let pendingPayment = "com.feelter.pendingPayment"
        static let isPaymentInProgress = "com.feelter.isPaymentInProgress"
    }

    // MARK: - Payment State
    struct PendingPayment: Codable {
        let filterId: String
        let orderCode: String
        let totalPrice: Int
        let createdAt: Date

        /// 결제 생성 후 일정 시간이 지나면 만료 처리 (24시간)
        var isExpired: Bool {
            let expirationInterval: TimeInterval = 24 * 60 * 60 // 24시간
            return Date().timeIntervalSince(createdAt) > expirationInterval
        }
    }

    // MARK: - Public Methods
    /// 주문 생성 시 결제 상태 저장
    func savePendingPayment(filterId: String, orderCode: String, totalPrice: Int) {
        let payment = PendingPayment(
            filterId: filterId,
            orderCode: orderCode,
            totalPrice: totalPrice,
            createdAt: Date()
        )

        do {
            let data = try JSONEncoder().encode(payment)
            UserDefaults.standard.set(data, forKey: Keys.pendingPayment)
        } catch {
        }
    }

    /// 결제 완료 시 저장된 상태 삭제
    func clearPendingPayment() {
        UserDefaults.standard.removeObject(forKey: Keys.pendingPayment)
    }

    /// 앱 재실행 시 미완료 결제 확인
    func getPendingPayment() -> PendingPayment? {
        guard let data = UserDefaults.standard.data(forKey: Keys.pendingPayment) else {
            return nil
        }

        do {
            let payment = try JSONDecoder().decode(PendingPayment.self, from: data)

            // 만료된 결제는 자동 삭제
            if payment.isExpired {
                clearPendingPayment()
                return nil
            }

            return payment
        } catch {
            // 디코딩 실패 시 손상된 데이터 삭제
            clearPendingPayment()
            return nil
        }
    }

    /// 미완료 결제가 있는지 확인
    func hasPendingPayment() -> Bool {
        return getPendingPayment() != nil
    }

    // MARK: - Payment Progress State
    /// 결제 진행 시작 (PG 결제 화면 표시 시)
    func setPaymentInProgress() {
        UserDefaults.standard.set(true, forKey: Keys.isPaymentInProgress)
    }

    /// 결제 진행 완료/취소 (결과 수신 후)
    func clearPaymentInProgress() {
        UserDefaults.standard.removeObject(forKey: Keys.isPaymentInProgress)
    }

    /// 결제 진행 중인지 확인
    func isPaymentInProgress() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.isPaymentInProgress)
    }
}
