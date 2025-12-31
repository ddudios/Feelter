//
//  AppFont.swift
//  Feelter
//
//  Created by Suji Jang on 12/28/25.
//

import UIKit

enum AppFont {
    /// Pretendard 프리텐다드
    enum Pretendard {
        static func bold(_ size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Bold.otf", size: size)
            ?? UIFont.systemFont(ofSize: size)
        }
        
        static func medium(_ size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Medium.otf", size: size)
            ?? UIFont.systemFont(ofSize: size)
        }
        
        static func regular(_ size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Regular.otf", size: size)
            ?? UIFont.systemFont(ofSize: size)
        }
    }
    
    /// Mulgyeol 학교안심 물결체
    enum Mulgyeol {
        static func bold(_ size: CGFloat) -> UIFont {
            UIFont(name: "HakgyoansimMulgyeolOTFB", size: size)
            ?? UIFont.systemFont(ofSize: size)
        }
        
        static func regular(_ size: CGFloat) -> UIFont {
            UIFont(name: "HakgyoansimMulgyeolOTFR.otf", size: size)
            ?? UIFont.systemFont(ofSize: size)
        }
    }
}
