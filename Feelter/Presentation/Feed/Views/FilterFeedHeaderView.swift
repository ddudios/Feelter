//
//  FilterFeedHeaderView.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import UIKit
import SnapKit

final class FilterFeedHeaderView: UICollectionReusableView {

    static let identifier = String(describing: FilterFeedHeaderView.self)

    private enum Layout {
        static let horizontalInset: CGFloat = Spacing.padding
        static let buttonHeight: CGFloat = 28
    }

    var onLayoutModeTapped: (() -> Void)?

    private let titleLabel = SectionTitleLabel(title: "Filter Feed")

    private let modeButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = TextStyle.Pretendard.body2
        button.setTitleColor(.Feelter.gray60, for: .normal)
        button.contentHorizontalAlignment = .right
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(modeTitle: String) {
        modeButton.setTitle(modeTitle, for: .normal)
    }

    private func configureHierarchy() {
        addSubview(titleLabel)
        addSubview(modeButton)
        modeButton.addTarget(self, action: #selector(modeButtonTapped), for: .touchUpInside)
    }

    private func configureLayout() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.horizontalInset)
            make.centerY.equalToSuperview()
        }

        modeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.centerY.equalToSuperview()
            make.height.equalTo(Layout.buttonHeight)
        }
    }

    private func configureView() {
        backgroundColor = .clear
    }

    @objc private func modeButtonTapped() {
        onLayoutModeTapped?()
    }
}
