//
//  KeychainManager.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation
import Security

final class KeychainManager {
    
    static let shared = KeychainManager()
    private init() {}
    
    private let service = "com.wkdtnwl.Feelter"
    
    // 1. 저장 (Create + Update)
    func save(token: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        // 기존 항목 삭제 (중복 방지)
        SecItemDelete(query as CFDictionary)
        
        // 새 항목 추가
        SecItemAdd(query as CFDictionary, nil)
    }
    
    // 2. 읽기 (Read)
    func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    // 3. 삭제 (Delete - 로그아웃 시 사용)
    func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
