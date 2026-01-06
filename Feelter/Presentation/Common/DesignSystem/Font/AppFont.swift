//
//  AppFont.swift
//  Feelter
//
//  Created by Suji Jang on 12/28/25.
//

import UIKit

enum AppFont {

    // MARK: - Debug Helper
    /// 앱에 등록된 모든 폰트 패밀리 네임 출력 (디버그용)
    static func printAvailableFonts() {
        UIFont.familyNames.sorted().forEach { familyName in
            print("Font Family: \(familyName)")
            let fontNames = UIFont.fontNames(forFamilyName: familyName)
            fontNames.forEach { fontName in
                print("\(fontName)")
            }
        }
    }
    
    //MARK: - Custom Font
    /// Pretendard 프리텐다드
    enum Pretendard {
        static func bold(_ size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Bold", size: size)
            ?? UIFont.italicSystemFont(ofSize: size)
        }

        static func medium(_ size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Medium", size: size)
            ?? UIFont.italicSystemFont(ofSize: size)
        }

        static func regular(_ size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Regular", size: size)
            ?? UIFont.italicSystemFont(ofSize: size)
        }
        
        static func semibold(_ size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-SemiBold", size: size)
            ?? UIFont.italicSystemFont(ofSize: size)
        }
    }
    
    /// Mulgyeol 학교안심 물결체
    enum Mulgyeol {
        static func bold(_ size: CGFloat) -> UIFont {
            UIFont(name: "OTHakgyoansimMulgyeolB", size: size)
            ?? UIFont.italicSystemFont(ofSize: size)
        }

        static func regular(_ size: CGFloat) -> UIFont {
            UIFont(name: "OTHakgyoansimMulgyeolR", size: size)
            ?? UIFont.italicSystemFont(ofSize: size)
        }
    }
}
