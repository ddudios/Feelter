//
//  FilterFeedCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import UIKit
import SnapKit
import Kingfisher

final class FilterFeedCell: BaseCollectionViewCell {

    var onLikeTapped: ((String, Bool) -> Void)?
    private var currentFilter: FilterSummary?

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
        button.setImage(UIImage(named: "Like_Empty"), for: .normal)
        button.setImage(UIImage(named: "Like_Fill"), for: .selected)
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
        let label = UILabel()
        label.font = TextStyle.Pretendard.body4
        label.textColor = .Feelter.gray45
        return label
    }()

    private let creatorNameLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body4
        label.textColor = .Feelter.gray30
        return label
    }()

    private let descriptionLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body4
        label.textColor = .Feelter.gray60
        label.numberOfLines = 2
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

    override func configureLayout() {
        thumbnailImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(80)
        }

        likeButton.snp.makeConstraints { make in
            make.top.equalTo(thumbnailImageView.snp.top).offset(8)
            make.trailing.equalTo(thumbnailImageView.snp.trailing).offset(-8)
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(thumbnailImageView.snp.top)
            make.leading.equalTo(thumbnailImageView.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-20)
        }

        categoryLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
        }

        creatorNameLabel.snp.makeConstraints { make in
            make.top.equalTo(categoryLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(creatorNameLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-20)
        }
    }

    @objc private func likeButtonTapped() {
        guard let filter = currentFilter else { return }
        onLikeTapped?(filter.id, filter.isLiked)
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
