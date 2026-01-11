//
//  ChatMessageCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import UIKit
import SnapKit

struct ChatMessageViewItem {
    let id: String
    let text: String?
    let images: [ChatImageSource]
    let date: Date
    let isOutgoing: Bool
    var status: MessageSendStatus
    var showsTime: Bool
}

enum ChatImageSource {
    case local(UIImage)
    case remote(String)
}

final class ChatMessageCell: UITableViewCell {

    var onRetryTapped: (() -> Void)?

    private enum Layout {
        static let profileSize: CGFloat = 36
        static let stackSpacing: CGFloat = 8
        static let bubbleSpacing: CGFloat = 6
        static let bubbleCornerRadius: CGFloat = Radius.l
    }

    private let profileImageView = UIImageView()
    private let bubbleContainerView = UIView()
    private let bubbleStackView = UIStackView()
    private let messageLabel = PaddingLabel()
    private let imageGridView = ChatImageGridView()
    private let timeLabel = UILabel()
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let statusStackView = UIStackView()
    private let horizontalStackView = UIStackView()
    private let spacerView = UIView()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onRetryTapped = nil
        profileImageView.image = UIImage.TabBar.profileFill
        messageLabel.text = nil
        timeLabel.text = nil
        statusLabel.text = nil
        retryButton.isHidden = true
    }

    func configure(with item: ChatMessageViewItem, opponentProfileImagePath: String?) {
        configureMessageContent(text: item.text, images: item.images)
        configureTimeLabel(date: item.date, showsTime: item.showsTime)
        configureStatus(for: item.status, showsTime: item.showsTime)
        configureLayoutDirection(isOutgoing: item.isOutgoing)
        configureColors(isOutgoing: item.isOutgoing)

        if item.isOutgoing {
            profileImageView.image = nil
        } else if let path = opponentProfileImagePath, !path.isEmpty {
            profileImageView.setFeelterImage(with: path)
        } else {
            profileImageView.image = UIImage.TabBar.profileFill
        }
    }

    private func configureHierarchy() {
        contentView.addSubview(horizontalStackView)
        bubbleContainerView.addSubview(bubbleStackView)
        bubbleStackView.addArrangedSubview(imageGridView)
        bubbleStackView.addArrangedSubview(messageLabel)
        statusStackView.addArrangedSubview(statusLabel)
        statusStackView.addArrangedSubview(retryButton)
    }

    private func configureLayout() {
        horizontalStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        profileImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.profileSize)
        }

        bubbleStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        retryButton.snp.makeConstraints { make in
            make.width.height.equalTo(18)
        }
    }

    private func configureView() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = Layout.profileSize / 2
        profileImageView.backgroundColor = .Feelter.gray90

        bubbleContainerView.layer.cornerRadius = Layout.bubbleCornerRadius
        bubbleContainerView.clipsToBounds = true
        bubbleContainerView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        bubbleContainerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        bubbleStackView.axis = .vertical
        bubbleStackView.spacing = Layout.bubbleSpacing

        messageLabel.font = TextStyle.Pretendard.body2
        messageLabel.textColor = .Feelter.gray0
        messageLabel.numberOfLines = 0
        messageLabel.padding = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        timeLabel.font = TextStyle.Pretendard.caption1
        timeLabel.textColor = .Feelter.gray60

        statusLabel.font = TextStyle.Pretendard.caption2
        statusLabel.textColor = .Feelter.gray60

        retryButton.tintColor = .Feelter.gray60
        retryButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)

        statusStackView.axis = .horizontal
        statusStackView.spacing = 4
        statusStackView.alignment = .center

        horizontalStackView.axis = .horizontal
        horizontalStackView.alignment = .bottom
        horizontalStackView.spacing = Layout.stackSpacing
    }

    private func configureMessageContent(text: String?, images: [ChatImageSource]) {
        if let text, !text.isEmpty {
            messageLabel.text = text
            messageLabel.isHidden = false
        } else {
            messageLabel.text = nil
            messageLabel.isHidden = true
        }

        if images.isEmpty {
            imageGridView.isHidden = true
        } else {
            imageGridView.isHidden = false
            imageGridView.configure(with: images)
        }
    }

    private func configureTimeLabel(date: Date, showsTime: Bool) {
        timeLabel.text = Self.timeFormatter.string(from: date)
        timeLabel.isHidden = !showsTime
    }

    private func configureStatus(for status: MessageSendStatus, showsTime: Bool) {
        let shouldShowStatus = showsTime && status != .sent
        statusStackView.isHidden = !shouldShowStatus

        if shouldShowStatus {
            statusLabel.text = status.displayText
        } else {
            statusLabel.text = nil
        }

        retryButton.isHidden = !showsTime || status != .failed
    }

    private func configureLayoutDirection(isOutgoing: Bool) {
        horizontalStackView.arrangedSubviews.forEach { view in
            horizontalStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if isOutgoing {
            horizontalStackView.addArrangedSubview(spacerView)
            horizontalStackView.addArrangedSubview(statusStackView)
            horizontalStackView.addArrangedSubview(timeLabel)
            horizontalStackView.addArrangedSubview(bubbleContainerView)
        } else {
            horizontalStackView.addArrangedSubview(profileImageView)
            horizontalStackView.addArrangedSubview(bubbleContainerView)
            horizontalStackView.addArrangedSubview(timeLabel)
            horizontalStackView.addArrangedSubview(spacerView)
        }

        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        statusStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusStackView.setContentHuggingPriority(.required, for: .horizontal)
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func configureColors(isOutgoing: Bool) {
        bubbleContainerView.backgroundColor = isOutgoing ? .Feelter.brightTurquoise : .Feelter.deepTurquoise
    }

    @objc private func retryButtonTapped() {
        onRetryTapped?()
    }
}
