//
//  FilterPresetsCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/9/26.
//

import UIKit
import SnapKit

final class FilterPresetsCell: BaseCollectionViewCell {
    private let containerView = FilterPresetsContainerView()

    override func configureHierarchy() {
        contentView.addSubview(containerView)
    }

    override func configureLayout() {
        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(200)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        containerView.reset()
    }

    func configure(values: FilterValues?, isLocked: Bool) {
        containerView.configure(values: values)
        containerView.setLocked(isLocked)
    }
}
