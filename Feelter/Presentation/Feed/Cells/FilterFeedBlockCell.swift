//
//  FilterFeedBlockCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import UIKit
import SnapKit
import Kingfisher

final class FilterFeedBlockCell: BaseCollectionViewCell {

    var onLikeTapped: ((String, Bool) -> Void)?
    private var currentFilter: FilterSummary?

    private let thumbnailImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.backgroundColor = .Feelter.gray90
        return imageView
    }()

    private let titleLabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.body1
        label.textColor = .Feelter.gray0
        label.numberOfLines = 2
        return label
    }()

    private let creatorNameLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body4
        label.textColor = .Feelter.gray60
        return label
    }()

    private let likeButton = {
        let button = UIButton(type: .custom)
        button.tintColor = .Feelter.gray0
        button.setImage(UIImage.Icon.likeEmpty, for: .normal)
        button.setImage(UIImage.Icon.likeFill, for: .selected)
        return button
    }()

    private let likeCountLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body4
        label.textColor = .Feelter.gray0
        return label
    }()

    private lazy var likeStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [likeButton, likeCountLabel])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 4
        return stackView
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
        thumbnailImageView.addSubview(titleLabel)
        thumbnailImageView.addSubview(likeStackView)
        contentView.addSubview(creatorNameLabel)
    }

    override func configureLayout() {
        thumbnailImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }

        likeStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-12)
        }

        likeButton.snp.makeConstraints { make in
            make.width.height.equalTo(18)
        }

        creatorNameLabel.snp.makeConstraints { make in
            make.top.equalTo(thumbnailImageView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
    }

    @objc private func likeButtonTapped() {
        guard let filter = currentFilter else { return }
        onLikeTapped?(filter.id, filter.isLiked)
    }

    func configure(with filter: FilterSummary) {
        currentFilter = filter

        thumbnailImageView.setFeelterImage(with: filter.mainImageURL)
        titleLabel.text = filter.title
        creatorNameLabel.text = filter.creator.nickname
        likeCountLabel.text = "\(filter.likeCount)"
        likeButton.isSelected = filter.isLiked
    }
}
