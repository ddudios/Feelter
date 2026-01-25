//
//  BottomGradientView.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import UIKit

final class BottomGradientView: UIView {
    // 이 뷰의 'Layer' 자체를 CAGradientLayer로 교체
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    private let bottomColor: UIColor

    init(bottomColor: UIColor? = nil) {
        self.bottomColor = bottomColor ?? UIColor.Feelter.gray100 ?? .black
        super.init(frame: .zero)
        setupGradient()
    }

    override init(frame: CGRect) {
        self.bottomColor = UIColor.Feelter.gray100 ?? .black
        super.init(frame: frame)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupGradient() {
        guard let gradientLayer = self.layer as? CAGradientLayer else { return }

        gradientLayer.colors = [
            UIColor.clear.cgColor,
            bottomColor.cgColor
        ]

        // 방향 설정 (위 -> 아래)
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)

        // 터치 이벤트 통과시키기
        self.isUserInteractionEnabled = false
    }
}
