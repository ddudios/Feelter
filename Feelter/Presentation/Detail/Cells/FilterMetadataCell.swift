//
//  FilterMetadataContainerCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/9/26.
//

import UIKit
import SnapKit

final class FilterMetadataCell: BaseCollectionViewCell {
    private let cardBackgroundView = FilterMetadataContainerView()

    override func configureHierarchy() {
        contentView.addSubview(cardBackgroundView)
    }

    override func configureLayout() {
        cardBackgroundView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(140)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardBackgroundView.reset()
    }

    func configure(metadata: PhotoMetadata) {
        cardBackgroundView.configure(metadata: metadata)
    }
}
