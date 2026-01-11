//
//  Notification+Extension.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

extension Notification.Name {
    /// 미완료 결제가 감지되었을 때 발송되는 노티피케이션
    /// userInfo: ["filterId": String, "orderCode": String, "totalPrice": Int]
    static let pendingPaymentDetected = Notification.Name("com.feelter.pendingPaymentDetected")
}
