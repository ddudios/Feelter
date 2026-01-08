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

    convenience init(padding: UIEdgeInsets) {
        self.init()
        self.padding = padding
        self.textAlignment = .center
    }

    // 2. 텍스트 그릴 때 여백 적용
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }

    // 3. 오토레이아웃 크기 계산 시 여백 포함
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + padding.left + padding.right,
                      height: size.height + padding.top + padding.bottom)
    }

    // 4. 레이아웃이 잡힐 때마다 둥글게 처리 (캡슐 모양 핵심)
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.masksToBounds = true
        layer.cornerRadius = bounds.height / 2
    }
}
