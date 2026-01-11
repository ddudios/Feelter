//
//  SendMessageRequestDTO.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation

struct SendMessageRequestDTO: Encodable {
    /// 메시지 내용 (텍스트)
    /// - 텍스트 없이 파일만 보내는 경우 빈 문자열("") 또는 nil 처리가 필요할 수 있으나,
    ///   Router에서 content를 String으로 받고 있으므로 그대로 전달합니다.
    let content: String?
    
    /// 업로드된 파일 경로 배열
    let files: [String]?
}
