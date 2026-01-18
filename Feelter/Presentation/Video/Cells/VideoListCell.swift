//
//  VideoListCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import UIKit
import SnapKit

final class VideoListCell: BaseCollectionViewCell {

    private enum Layout {
        static let thumbnailAspectRatio: CGFloat = 9.0 / 16.0
        static let likeButtonSize: CGFloat = 28
        static let textTopSpacing: CGFloat = 12
        static let textSpacing: CGFloat = 6
        static let bottomInset: CGFloat = 16
        static let likeButtonSpacing: CGFloat = 8
    }

    var onLikeTapped: ((String, Bool) -> Void)?

    private var currentVideo: VideoSummary?

    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .Feelter.gray90
        return imageView
    }()

    private let likeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.Icon.likeEmpty, for: .normal)
        button.setImage(UIImage.Icon.likeFill, for: .selected)
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body1
        label.textColor = .Feelter.gray0
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .Feelter.gray60
        label.numberOfLines = 1
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
        contentView.addSubview(titleLabel)
        contentView.addSubview(metadataLabel)
        contentView.addSubview(likeButton)
    }

    override func configureLayout() {
        thumbnailImageView.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview()
            make.height.equalTo(thumbnailImageView.snp.width).multipliedBy(Layout.thumbnailAspectRatio)
        }

        likeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.top.equalTo(titleLabel.snp.top)
            make.width.height.equalTo(Layout.likeButtonSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(thumbnailImageView.snp.bottom).offset(Layout.textTopSpacing)
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalTo(likeButton.snp.leading).offset(-Layout.likeButtonSpacing)
        }

        metadataLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.textSpacing)
            make.leading.equalTo(titleLabel.snp.leading)
            make.trailing.equalToSuperview().offset(-8)
            make.bottom.equalToSuperview().inset(Layout.bottomInset)
        }
    }

    override func configureView() {
        super.configureView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentVideo = nil
        onLikeTapped = nil
        thumbnailImageView.image = nil
        likeButton.isSelected = false
        updateLikeButtonAppearance(isLiked: false)
    }

    func configure(with video: VideoSummary) {
        currentVideo = video
        thumbnailImageView.setFeelterImage(with: video.thumbnailURL)
        titleLabel.text = video.title
        metadataLabel.text = "조회수 \(viewCountText(video.viewCount)) · \(video.createdAt.relativeDescription())"
        likeButton.isSelected = video.isLiked
        updateLikeButtonAppearance(isLiked: video.isLiked)
    }

    @objc private func likeButtonTapped() {
        guard let video = currentVideo else { return }
        onLikeTapped?(video.id, likeButton.isSelected)
    }

    private func updateLikeButtonAppearance(isLiked: Bool) {
        likeButton.tintColor = isLiked
        ? UIColor.Feelter.brightTurquoise
        : UIColor.Feelter.gray60
    }

    private func viewCountText(_ count: Int) -> String {
        if count >= 10_000 {
            return "\(formatShortCount(Double(count) / 10_000))만회"
        }
        if count >= 1_000 {
            return "\(formatShortCount(Double(count) / 1_000))천회"
        }
        return "\(count)회"
    }

    private func formatShortCount(_ value: Double) -> String {
        let formatted = String(format: "%.1f", value)
        if formatted.hasSuffix(".0") {
            return String(formatted.dropLast(2))
        }
        return formatted
    }
}
