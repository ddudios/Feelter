//
//  Color+Extension.swift
//  Feelter
//
//  Created by Suji Jang on 12/27/25.
//

import UIKit

extension UIColor {

    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value) else {
            return nil
        }

        switch hex.count {
        case 3: // RGB (12-bit)
            let r = CGFloat((value >> 8) & 0xF) / 15.0
            let g = CGFloat((value >> 4) & 0xF) / 15.0
            let b = CGFloat(value & 0xF) / 15.0
            self.init(red: r, green: g, blue: b, alpha: 1)

        case 6: // RRGGBB (24-bit)
            let r = CGFloat((value >> 16) & 0xFF) / 255.0
            let g = CGFloat((value >> 8) & 0xFF) / 255.0
            let b = CGFloat(value & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1)

        case 8: // AARRGGBB (32-bit)
            let a = CGFloat((value >> 24) & 0xFF) / 255.0
            let r = CGFloat((value >> 16) & 0xFF) / 255.0
            let g = CGFloat((value >> 8) & 0xFF) / 255.0
            let b = CGFloat(value & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)

        default:
            return nil
        }
    }
}

extension UIColor {
    enum Feelter {
        static let blackTurquoise = UIColor(hex: "#1F2527")
        static let deepTurquoise = UIColor(hex: "#293235")
        static let brightTurquoise = UIColor(hex: "#315C6B")
        static let shadow = UIColor(hex: "#0D0D0D")
        
        static let gray0 = UIColor(hex: "#FFFFFF")
        static let gray15 = UIColor(hex: "#F9F9F9")
        static let gray30 = UIColor(hex: "#EAEAEA")
        static let gray45 = UIColor(hex: "#D8D6D7")
        static let gray60 = UIColor(hex: "#ABABAE")
        static let gray75 = UIColor(hex: "#6A6A6E")
        static let gray90 = UIColor(hex: "#434347")
        static let gray100 = UIColor(hex: "#0B0B0B")
    }
}
