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

    /// 새 필터가 생성되었을 때 발송되는 노티피케이션
    /// userInfo: ["filter": FilterDetail]
    static let filterDidCreate = Notification.Name("com.feelter.filterDidCreate")

    /// 필터가 수정되었을 때 발송되는 노티피케이션
    /// userInfo: ["filter": FilterDetail]
    static let filterDidUpdate = Notification.Name("com.feelter.filterDidUpdate")

    /// 필터가 삭제되었을 때 발송되는 노티피케이션
    /// userInfo: ["filterId": String]
    static let filterDidDelete = Notification.Name("com.feelter.filterDidDelete")
}
