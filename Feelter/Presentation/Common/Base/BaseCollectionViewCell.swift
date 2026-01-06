//
//  BaseCollectionViewCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import UIKit

class BaseCollectionViewCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureHierarchy() { }
    func configureLayout() { }
    func configureView() {
        contentView.backgroundColor = .clear
    }
}
