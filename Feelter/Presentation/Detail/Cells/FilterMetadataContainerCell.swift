//
//  FilterMetadataContainerCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/9/26.
//

import UIKit

final class FilterMetadataContainerCell: BaseCollectionViewCell {
    private let cardBackgroundView = FilterMetadataContainerView()

    override func configureHierarchy() {
        contentView.addSubview(cardBackgroundView)
    }

    override func configureLayout() {
        cardBackgroundView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(120)
        }
    }
}
