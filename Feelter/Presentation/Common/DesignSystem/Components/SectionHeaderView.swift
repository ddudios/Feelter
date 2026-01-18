//
//  SectionHeaderView.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import UIKit
import SnapKit

final class SectionHeaderView: UICollectionReusableView {
    static let identifier = "SectionHeaderView"

    private let titleLabel = SectionTitleLabel(title: "")

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().inset(20)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().inset(8)
        }
    }

    func configure(with title: String) {
        titleLabel.text = title
    }
}
