//
//  FilterCreatorInfoCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/9/26.
//

import UIKit
import SnapKit

final class FilterCreatorInfoCell: BaseCollectionViewCell {
    var onMessageTapped: ((String) -> Void)?
    private var currentCreatorId: String?

    private let dividerView = UIView()
    private let profileImageView = UIImageView()
    private let nameLabel = UILabel()
    private let nicknameLabel = UILabel()
    private let messageButton = UIButton(type: .custom)
    private let tagWrapView = TagWrapView()
    private let descriptionLabel = UILabel()

    private lazy var nameStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, nicknameLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        return stackView
    }()

    override func configureHierarchy() {
        contentView.addSubview(dividerView)
        contentView.addSubview(profileImageView)
        contentView.addSubview(nameStackView)
        contentView.addSubview(messageButton)
        contentView.addSubview(tagWrapView)
        contentView.addSubview(descriptionLabel)
    }

    override func configureLayout() {
        dividerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Spacing.padding)
            make.height.equalTo(1)
        }

        profileImageView.snp.makeConstraints { make in
            make.top.equalTo(dividerView.snp.bottom).offset(20)
            make.leading.equalToSuperview().inset(16)
            make.width.height.equalTo(72)
        }

        messageButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(profileImageView)
            make.width.height.equalTo(44)
        }

        nameStackView.snp.makeConstraints { make in
            make.leading.equalTo(profileImageView.snp.trailing).offset(16)
            make.trailing.lessThanOrEqualTo(messageButton.snp.leading).offset(-12)
            make.centerY.equalTo(profileImageView)
        }

        tagWrapView.snp.makeConstraints { make in
            make.top.equalTo(profileImageView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(tagWrapView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(16)
        }
    }

    override func configureView() {
        super.configureView()

        dividerView.backgroundColor = .Feelter.deepTurquoise

        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 36
        profileImageView.layer.borderWidth = 1
        profileImageView.layer.borderColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5).cgColor
        profileImageView.backgroundColor = .Feelter.gray100

        nameLabel.font = TextStyle.Mulgyeol.body1
        nameLabel.textColor = .Feelter.gray30

        nicknameLabel.font = TextStyle.Pretendard.body1
        nicknameLabel.textColor = .Feelter.gray75

        messageButton.backgroundColor = .Feelter.deepTurquoise
        messageButton.layer.cornerRadius = 12
        messageButton.layer.cornerCurve = .continuous
        messageButton.tintColor = .Feelter.gray30
        messageButton.setImage(UIImage.Icon.message, for: .normal)
        messageButton.addTarget(self, action: #selector(messageButtonTapped), for: .touchUpInside)

        descriptionLabel.font = TextStyle.Pretendard.caption2
        descriptionLabel.textColor = .Feelter.gray60
        descriptionLabel.numberOfLines = 0
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = UIImage(named: "appIcon")
        nameLabel.text = nil
        nicknameLabel.text = nil
        descriptionLabel.text = nil
        tagWrapView.configure(tags: [])
        currentCreatorId = nil
        onMessageTapped = nil
        messageButton.isHidden = false
    }

    func configure(creator: Creator, description: String, isOwnFilter: Bool = false) {
        currentCreatorId = creator.id
        nameLabel.text = creator.name
        nicknameLabel.text = creator.nickname
        descriptionLabel.text = description
        tagWrapView.configure(tags: creator.hashTags)

        profileImageView.image = UIImage(named: "appIcon")
        profileImageView.backgroundColor = .clear
        if let path = creator.profileImageURL, !path.isEmpty {
            profileImageView.setFeelterImage(with: path)
        }

        // 본인의 필터인 경우 메시지 버튼 숨김
        messageButton.isHidden = isOwnFilter
    }

    @objc private func messageButtonTapped() {
        guard let creatorId = currentCreatorId else { return }
        onMessageTapped?(creatorId)
    }
}

private final class TagWrapView: UIView {
    private enum Layout {
        static let horizontalSpacing: CGFloat = 8
        static let verticalSpacing: CGFloat = 8
    }

    private var tagLabels: [CapsuleLabel] = []
    private var cachedSize: CGSize = .zero

    func configure(tags: [String]) {
        tagLabels.forEach { $0.removeFromSuperview() }
        tagLabels.removeAll()

        for tag in tags {
            let label = CapsuleLabel(padding: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))
            label.font = TextStyle.Pretendard.caption2
            label.textColor = .Feelter.gray60
            label.backgroundColor = .Feelter.blackTurquoise
            label.text = tag.hasPrefix("#") ? tag : "#\(tag)"
            addSubview(label)
            tagLabels.append(label)
        }

        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutTagLabels()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let targetWidth = size.width > 0 ? size.width : bounds.width
        guard targetWidth > 0 else { return .zero }
        return computeSize(forWidth: targetWidth)
    }

    override var intrinsicContentSize: CGSize {
        if bounds.width > 0 {
            return computeSize(forWidth: bounds.width)
        }
        return cachedSize
    }

    private func layoutTagLabels() {
        let maxWidth = bounds.width
        guard maxWidth > 0 else { return }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for label in tagLabels {
            let labelSize = label.intrinsicContentSize
            if x + labelSize.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + Layout.verticalSpacing
                rowHeight = 0
            }

            label.frame = CGRect(x: x, y: y, width: labelSize.width, height: labelSize.height)
            x += labelSize.width + Layout.horizontalSpacing
            rowHeight = max(rowHeight, labelSize.height)
        }

        let totalHeight = rowHeight > 0 ? y + rowHeight : 0
        let newSize = CGSize(width: maxWidth, height: totalHeight)
        if cachedSize != newSize {
            cachedSize = newSize
            invalidateIntrinsicContentSize()
        }
    }

    private func computeSize(forWidth width: CGFloat) -> CGSize {
        guard width > 0 else { return .zero }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for label in tagLabels {
            let labelSize = label.intrinsicContentSize
            if x + labelSize.width > width, x > 0 {
                x = 0
                y += rowHeight + Layout.verticalSpacing
                rowHeight = 0
            }
            x += labelSize.width + Layout.horizontalSpacing
            rowHeight = max(rowHeight, labelSize.height)
        }

        let totalHeight = rowHeight > 0 ? y + rowHeight : 0
        return CGSize(width: width, height: totalHeight)
    }
}
