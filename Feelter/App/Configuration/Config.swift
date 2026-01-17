//
//  Config.swift
//  Feelter
//
//  Created by Suji Jang on 1/4/26.
//

import Foundation

struct Config {
    // Info.plist에서 값을 읽어오는 헬퍼 메서드
    private static func infoDictionaryValue(for key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String else {
            fatalError("Key '\(key)' not found in Info.plist")
        }
        return value
    }

    // 외부에서 접근할 속성
    static var baseURL: URL {
        let urlString = infoDictionaryValue(for: "BaseURL")
        guard let url = URL(string: urlString) else {
            fatalError("BaseURL is invalid")
        }
        return url
    }
    
    static var apiKey: String {
        return infoDictionaryValue(for: "APIKey")
    }
    
    static var kakaoLoginKey: String {
        return infoDictionaryValue(for: "KakaoLoginKey")
    }
}
