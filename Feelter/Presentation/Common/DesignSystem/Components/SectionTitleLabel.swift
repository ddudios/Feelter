//
//  SectionTitleLabel.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import UIKit

final class SectionTitleLabel: UILabel {
    init(title: String) {
        super.init(frame: .zero)
        text = title
        font = TextStyle.Pretendard.body1
        textColor = .Feelter.gray60
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
