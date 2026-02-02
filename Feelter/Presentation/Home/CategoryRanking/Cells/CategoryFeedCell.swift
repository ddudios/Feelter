//
//  CategoryFeedCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import UIKit
import SnapKit
import Kingfisher

final class CategoryFeedCell: BaseCollectionViewCell, UIGestureRecognizerDelegate {

    var onTap: ((String) -> Void)?
    var onLikeTapped: ((String, Bool) -> Void)?
    private var currentFilter: FilterSummary?
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        recognizer.delegate = self
        return recognizer
    }()

    private let thumbnailImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .Feelter.gray90
        return imageView
    }()

    private let likeButton = {
        let button = UIButton(type: .custom)
        button.tintColor = .Feelter.gray0
        button.setImage(UIImage.Icon.likeEmpty, for: .normal)
        button.setImage(UIImage.Icon.likeFill, for: .selected)
        return button
    }()

    private let titleLabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.body1
        label.textColor = .Feelter.gray15
        label.numberOfLines = 1
        return label
    }()

    private let categoryLabel = {
        let label = CapsuleLabel()
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .Feelter.gray60
        label.backgroundColor = UIColor.Feelter.blackTurquoise
        return label
    }()

    private let creatorNameLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body1
        label.textColor = .Feelter.gray75
        return label
    }()

    private let descriptionLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .Feelter.gray60
        label.numberOfLines = 3
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        likeButton.addTarget(self, action: #selector(likeButtonTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureHierarchy() {
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(likeButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(categoryLabel)
        contentView.addSubview(creatorNameLabel)
        contentView.addSubview(descriptionLabel)
    }

    override func configureView() {
        super.configureView()
        contentView.addGestureRecognizer(tapGestureRecognizer)
    }

    override func configureLayout() {
        thumbnailImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.verticalEdges.equalToSuperview()
            make.width.equalTo(90)
            make.height.equalTo(110)
        }

        likeButton.snp.makeConstraints { make in
            make.bottom.equalTo(thumbnailImageView.snp.bottom).offset(-8)
            make.trailing.equalTo(thumbnailImageView.snp.trailing).offset(-8)
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(thumbnailImageView.snp.top).offset(5)
            make.leading.equalTo(thumbnailImageView.snp.trailing).offset(16)
        }

        categoryLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel.snp.centerY)
            make.leading.equalTo(titleLabel.snp.trailing).offset(6)
            make.trailing.lessThanOrEqualToSuperview()
        }

        creatorNameLabel.snp.makeConstraints { make in
            make.top.equalTo(categoryLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(creatorNameLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTap = nil
        onLikeTapped = nil
        currentFilter = nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let view = touch.view, view.isDescendant(of: likeButton) {
            return false
        }
        return true
    }

    @objc private func likeButtonTapped() {
        guard let filter = currentFilter else { return }
        onLikeTapped?(filter.id, filter.isLiked)
    }

    @objc private func handleTap() {
        guard let filter = currentFilter else { return }
        onTap?(filter.id)
    }

    func configure(with filter: FilterSummary) {
        currentFilter = filter

        thumbnailImageView.setFeelterImage(with: filter.mainImageURL)
        titleLabel.text = filter.title
        categoryLabel.text = "#\(filter.category.rawValue)"
        creatorNameLabel.text = filter.creator.nickname
        descriptionLabel.text = filter.description

        likeButton.isSelected = filter.isLiked
    }
}
