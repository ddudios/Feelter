//
//  FilterMetadataContainerView.swift
//  Feelter
//
//  Created by Suji Jang on 1/9/26.
//

import UIKit
import SnapKit

final class FilterMetadataContainerView: UIView {
    private enum Layout {
        static let headerHeight: CGFloat = 30
        static let horizontalInset: CGFloat = 8
        static let labelSpacing: CGFloat = 4
        static let dividerHeight: CGFloat = 1
    }

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let tagLabel = UILabel()
    private let dividerView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, tag: String) {
        titleLabel.text = title
        tagLabel.text = tag
    }

    private func configureHierarchy() {
        addSubview(headerView)
        addSubview(dividerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(tagLabel)
    }

    private func configureLayout() {
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.headerHeight)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(tagLabel.snp.leading).offset(-Layout.labelSpacing)
        }

        tagLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.centerY.equalToSuperview()
        }

        dividerView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.dividerHeight)
        }
    }

    private func configureView() {
        backgroundColor = .Feelter.blackTurquoise
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.borderWidth = 2
        layer.borderColor = UIColor.Feelter.blackTurquoise?.cgColor
        clipsToBounds = true

        headerView.backgroundColor = .Feelter.gray100

        titleLabel.font = TextStyle.Pretendard.semibold1
        titleLabel.textColor = .Feelter.deepTurquoise
        titleLabel.text = "Apple iPhone 16 Pro"

        tagLabel.font = TextStyle.Pretendard.semibold1
        tagLabel.textColor = .Feelter.deepTurquoise
        tagLabel.text = "EXIF"

        dividerView.backgroundColor = .Feelter.blackTurquoise
    }
}
