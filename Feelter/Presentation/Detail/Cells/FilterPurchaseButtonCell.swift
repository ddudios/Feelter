//
//  FilterPurchaseButtonCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/9/26.
//

import UIKit
import SnapKit

final class FilterPurchaseButtonCell: BaseCollectionViewCell {
    private let purchaseButton = FeelterButton(title: "결제하기")

    var onPurchaseButtonTapped: (() -> Void)?

    override func configureHierarchy() {
        contentView.addSubview(purchaseButton)
    }

    override func configureLayout() {
        purchaseButton.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(52)
        }
    }

    override func configureView() {
        super.configureView()
        purchaseButton.addTarget(self, action: #selector(purchaseButtonTapped), for: .touchUpInside)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        configure(isPurchased: false)
        onPurchaseButtonTapped = nil
    }

    @objc private func purchaseButtonTapped() {
        onPurchaseButtonTapped?()
    }

    func configure(isPurchased: Bool) {
        purchaseButton.titleLabel?.font = TextStyle.Pretendard.title1

        if isPurchased {
            purchaseButton.setTitle("구매완료", for: .normal)
            purchaseButton.isEnabled = false
        } else {
            purchaseButton.setTitle("결제하기", for: .normal)
            purchaseButton.isEnabled = true
        }
    }
}
