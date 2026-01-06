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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    private func setupGradient() {
        guard let gradientLayer = self.layer as? CAGradientLayer else { return }
        
        // 색상 설정 (옵셔널 처리 포함)
        let bottomColor = UIColor.Feelter.gray100 ?? .black
        
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
