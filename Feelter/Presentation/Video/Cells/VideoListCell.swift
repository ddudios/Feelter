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
        static let textTopSpacing: CGFloat = 12
        static let textSpacing: CGFloat = 6
        static let bottomInset: CGFloat = 16
    }

    private var currentVideo: VideoSummary?
    private var thumbnailHeightConstraint: Constraint?
    private var thumbnailBottomConstraint: Constraint?
    private var titleLabelTopConstraint: Constraint?
    private var metadataLabelBottomConstraint: Constraint?

    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .Feelter.gray90
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body1
        label.textColor = .Feelter.gray0
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .Feelter.gray60
        label.numberOfLines = 1
        return label
    }()

    // Featured video UI components
    private let gradientView: BottomGradientView = {
        let view = BottomGradientView(bottomColor: UIColor.black)
        view.isHidden = true
        return view
    }()

    private let featuredTitleLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .white
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let viewCountCapsuleLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.padding = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .white
        label.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    private let likeCountCapsuleLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.padding = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .white
        label.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    private let capsuleStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.isHidden = true
        return stackView
    }()

    private let featuredDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body2
        label.textColor = .white
        label.numberOfLines = 2
        label.isHidden = true
        return label
    }()

    private lazy var playButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular, scale: .large)
        button.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.isHidden = true
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureHierarchy() {
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(metadataLabel)

        // Featured video views
        contentView.addSubview(gradientView)
        gradientView.addSubview(featuredTitleLabel)
        gradientView.addSubview(capsuleStackView)
        capsuleStackView.addArrangedSubview(viewCountCapsuleLabel)
        capsuleStackView.addArrangedSubview(likeCountCapsuleLabel)
        gradientView.addSubview(featuredDescriptionLabel)
        gradientView.addSubview(playButton)
    }

    override func configureLayout() {
        thumbnailImageView.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview()
            thumbnailHeightConstraint = make.height.equalTo(thumbnailImageView.snp.width).multipliedBy(Layout.thumbnailAspectRatio).constraint
            thumbnailBottomConstraint = make.bottom.equalToSuperview().constraint
        }
        thumbnailBottomConstraint?.deactivate()

        titleLabel.snp.makeConstraints { make in
            titleLabelTopConstraint = make.top.equalTo(thumbnailImageView.snp.bottom).offset(Layout.textTopSpacing).constraint
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
        }

        metadataLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.textSpacing)
            make.leading.equalTo(titleLabel.snp.leading)
            make.trailing.equalToSuperview().offset(-8)
            metadataLabelBottomConstraint = make.bottom.equalToSuperview().inset(Layout.bottomInset).constraint
        }

        // Featured video layout
        gradientView.snp.makeConstraints { make in
            make.edges.equalTo(thumbnailImageView)
        }

        playButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(featuredTitleLabel.snp.centerY)
            make.width.height.equalTo(44)
        }

        featuredTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(playButton.snp.leading).offset(-12)
            make.bottom.equalTo(capsuleStackView.snp.top).offset(-8)
        }

        capsuleStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalTo(featuredDescriptionLabel.snp.top).offset(-8)
        }

        featuredDescriptionLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(thumbnailImageView.snp.trailing).inset(20)
            make.bottom.equalToSuperview().offset(-20)
        }
    }

    override func configureView() {
        super.configureView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentVideo = nil
        thumbnailImageView.image = nil

        // Reset thumbnail constraints to default
        thumbnailBottomConstraint?.deactivate()
        thumbnailHeightConstraint?.activate()

        // Reset normal video constraints to active
        titleLabelTopConstraint?.activate()
        metadataLabelBottomConstraint?.activate()
    }

    func configure(with video: VideoSummary, isFeatured: Bool = false) {
        currentVideo = video
        thumbnailImageView.setFeelterImage(with: video.thumbnailURL)

        if isFeatured {
            // Update thumbnail constraints for featured video
            thumbnailHeightConstraint?.deactivate()
            thumbnailBottomConstraint?.activate()

            // Deactivate normal video constraints
            titleLabelTopConstraint?.deactivate()
            metadataLabelBottomConstraint?.deactivate()

            // Show featured video UI
            gradientView.isHidden = false
            featuredTitleLabel.isHidden = false
            capsuleStackView.isHidden = false
            viewCountCapsuleLabel.isHidden = false
            likeCountCapsuleLabel.isHidden = false
            featuredDescriptionLabel.isHidden = false
            playButton.isHidden = false

            // Hide normal video UI
            titleLabel.isHidden = true
            metadataLabel.isHidden = true

            // Configure featured labels
            featuredTitleLabel.text = video.title
            viewCountCapsuleLabel.text = "조회수 \(viewCountText(video.viewCount))"
            likeCountCapsuleLabel.text = "좋아요 \(likeCountText(video.likeCount))"
            featuredDescriptionLabel.text = video.description
        } else {
            // Update thumbnail constraints for normal video
            thumbnailBottomConstraint?.deactivate()
            thumbnailHeightConstraint?.activate()

            // Activate normal video constraints
            titleLabelTopConstraint?.activate()
            metadataLabelBottomConstraint?.activate()

            // Show normal video UI
            gradientView.isHidden = true
            featuredTitleLabel.isHidden = true
            capsuleStackView.isHidden = true
            viewCountCapsuleLabel.isHidden = true
            likeCountCapsuleLabel.isHidden = true
            featuredDescriptionLabel.isHidden = true
            playButton.isHidden = true

            // Show and configure normal UI
            titleLabel.isHidden = false
            metadataLabel.isHidden = false

            titleLabel.text = video.title
            metadataLabel.text = "조회수 \(viewCountText(video.viewCount)) · \(video.createdAt.relativeDescription())"
        }
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

    private func likeCountText(_ count: Int) -> String {
        if count >= 10_000 {
            return "\(formatShortCount(Double(count) / 10_000))만"
        }
        if count >= 1_000 {
            return "\(formatShortCount(Double(count) / 1_000))천"
        }
        return "\(count)"
    }

    private func formatShortCount(_ value: Double) -> String {
        let formatted = String(format: "%.1f", value)
        if formatted.hasSuffix(".0") {
            return String(formatted.dropLast(2))
        }
        return formatted
    }
}
