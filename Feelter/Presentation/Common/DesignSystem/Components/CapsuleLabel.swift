//
//  CapsuleLabel.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import UIKit

final class CapsuleLabel: UILabel {
    // 1. 원하는 여백 설정 (상, 하, 좌, 우)
    private var padding = UIEdgeInsets(top: 4.0, left: 8.0, bottom: 4.0, right: 8.0)

    /// 정원 모양 강제 (width = height)
    private var forceCircle: Bool = false

    convenience init(padding: UIEdgeInsets, forceCircle: Bool = false) {
        self.init()
        self.padding = padding
        self.forceCircle = forceCircle
        self.textAlignment = .center
    }

    // 2. 텍스트 그릴 때 여백 적용
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }

    // 3. 오토레이아웃 크기 계산 시 여백 포함
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width += padding.left + padding.right
        size.height += padding.top + padding.bottom

        // 정원 모양 강제: width = height (더 큰 값으로 통일)
        if forceCircle {
            let maxDimension = max(size.width, size.height)
            size.width = maxDimension
            size.height = maxDimension
        }

        return size
    }

    // 4. 레이아웃이 잡힐 때마다 둥글게 처리
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.masksToBounds = true

        if forceCircle {
            // 정원: width와 height 중 작은 값의 절반
            layer.cornerRadius = min(bounds.width, bounds.height) / 2
        } else {
            // 캡슐: height의 절반
            layer.cornerRadius = bounds.height / 2
        }
    }
}
