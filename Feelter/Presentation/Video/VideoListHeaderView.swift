//
//  VideoListHeaderView.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import UIKit
import SnapKit

final class VideoListHeaderView: UICollectionReusableView {

    static let identifier = String(describing: VideoListHeaderView.self)

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .Feelter.gray30
        label.numberOfLines = 1
        return label
    }()

    private var titleTopConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, safeAreaTopInset: CGFloat) {
        titleLabel.text = title
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let targetSize = CGSize(
            width: layoutAttributes.size.width,
            height: UIView.layoutFittingCompressedSize.height
        )
        let size = systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        attributes.size = CGSize(width: layoutAttributes.size.width, height: ceil(size.height))
        return attributes
    }

    private func configureHierarchy() {
        addSubview(titleLabel)
    }

    private func configureLayout() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Spacing.padding)
            make.top.equalToSuperview().offset(60)
            make.bottom.equalToSuperview().inset(16)
        }
    }

    private func configureView() {
        backgroundColor = .clear
    }
}
