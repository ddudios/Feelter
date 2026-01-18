//
//  StringArrayValueTransformer.swift
//  Feelter
//
//  Created by Suji Jang on 1/13/26.
//

import Foundation

@objc(StringArrayValueTransformer)
final class StringArrayValueTransformer: NSSecureUnarchiveFromDataTransformer {

    /// Transformer 이름 (CoreData 모델에서 참조)
    static let name = NSValueTransformerName(rawValue: "StringArrayValueTransformer")

    /// 변환 가능한 클래스 타입 지정
    /// - Returns: [NSArray, NSString] - 배열과 문자열만 허용
    override static var allowedTopLevelClasses: [AnyClass] {
        return [NSArray.self, NSString.self]
    }

    /// ValueTransformer 등록
    /// 앱 시작 시 한 번만 호출하면 됨
    /// - Note: AppDelegate나 SceneDelegate에서 호출
    static func register() {
        let transformer = StringArrayValueTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)

    }
}
