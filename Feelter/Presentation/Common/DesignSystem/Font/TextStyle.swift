//
//  TextStyle.swift
//  Feelter
//
//  Created by Suji Jang on 12/28/25.
//

import Foundation

enum TextStyle {
    
    enum Pretendard {
        static let title1 = AppFont.Pretendard.bold(20)
        
        static let body1 = AppFont.Pretendard.medium(16)
        static let body2 = AppFont.Pretendard.medium(14)
        static let body3 = AppFont.Pretendard.medium(13)
        
        static let caption1 = AppFont.Pretendard.regular(12)
        static let caption2 = AppFont.Pretendard.regular(10)
        static let caption3 = AppFont.Pretendard.regular(8)
        
        static let semibold1 = AppFont.Pretendard.semibold(10)
    }
    
    enum Mulgyeol {
        static let title1 = AppFont.Mulgyeol.bold(32)
        static let body1 = AppFont.Mulgyeol.bold(20)
        static let caption1 = AppFont.Mulgyeol.regular(14)
    }
}
