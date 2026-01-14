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
        static let statusIconSize: CGFloat = 16
    }

    private let profileImageView = UIImageView()
    private let bubbleContainerView = UIView()
    private let bubbleStackView = UIStackView()
    private let messageLabel = PaddingLabel()
    private let imageGridView = ChatImageGridView()
    private let timeLabel = UILabel()
    private let readCountLabel = UILabel()
    private let timeStackView = UIStackView()
    private let statusLabel = UILabel()
    private let statusIconImageView = UIImageView()
    private let retryButton = UIButton(type: .system)
    private let statusStackView = UIStackView()
    private let horizontalStackView = UIStackView()
    private let spacerView = UIView()
    private var bubbleMaxWidthConstraint: Constraint?
    private var currentIsOutgoing = false

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
        currentIsOutgoing = false
        messageLabel.text = nil
        timeLabel.text = nil
        readCountLabel.text = nil
        readCountLabel.isHidden = true
        statusLabel.text = nil
        statusIconImageView.image = nil
        retryButton.isHidden = true
        imageGridView.configure(with: [])  // 이미지 그리드 초기화
    }

    func configure(with item: ChatMessageViewItem, opponentProfileImagePath: String?) {
        currentIsOutgoing = item.isOutgoing
        configureMessageContent(text: item.text, images: item.images)
        configureTimeLabel(date: item.date, showsTime: item.showsTime)
        configureStatus(for: item.status, showsTime: item.showsTime, isOutgoing: item.isOutgoing)
        configureLayoutDirection(isOutgoing: item.isOutgoing)
        configureColors(isOutgoing: item.isOutgoing)

        if item.isOutgoing {
            profileImageView.image = nil
        } else if let path = opponentProfileImagePath, !path.isEmpty {
            profileImageView.setFeelterImage(with: path)
        } else {
            profileImageView.image = UIImage(named: "appIcon")
        }
    }

    private func configureHierarchy() {
        contentView.addSubview(profileImageView)
        contentView.addSubview(horizontalStackView)
        bubbleContainerView.addSubview(bubbleStackView)
        bubbleStackView.addArrangedSubview(imageGridView)
        bubbleStackView.addArrangedSubview(messageLabel)
        timeStackView.addArrangedSubview(readCountLabel)
        timeStackView.addArrangedSubview(timeLabel)
        statusStackView.addArrangedSubview(statusIconImageView)
        statusStackView.addArrangedSubview(statusLabel)
        statusStackView.addArrangedSubview(retryButton)
    }

    private func configureLayout() {
        // 프로필 이미지: 상단 고정, 크기 고정 (셀 높이와 무관하게 36x36 유지)
        profileImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(4)
            make.leading.equalToSuperview().inset(16)
            make.width.equalTo(Layout.profileSize).priority(.required)
            make.height.equalTo(Layout.profileSize).priority(.required)
        }

        horizontalStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4).priority(.high)
            make.trailing.equalToSuperview().inset(16)
        }

        bubbleStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        statusIconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.statusIconSize)
        }

        retryButton.snp.makeConstraints { make in
            make.width.height.equalTo(10)
        }
    }

    private func configureView() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // 프로필 이미지 찌그러짐 방지 설정
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = Layout.profileSize / 2
        profileImageView.backgroundColor = .clear
        // 크기 고정을 위한 우선순위 설정 (늘어나거나 줄어들지 않도록)
        profileImageView.setContentHuggingPriority(.required, for: .vertical)
        profileImageView.setContentHuggingPriority(.required, for: .horizontal)
        profileImageView.setContentCompressionResistancePriority(.required, for: .vertical)
        profileImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        bubbleContainerView.layer.cornerRadius = Layout.bubbleCornerRadius
        bubbleContainerView.clipsToBounds = true
        bubbleContainerView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        bubbleContainerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        bubbleStackView.axis = .vertical
        bubbleStackView.spacing = Layout.bubbleSpacing

        messageLabel.font = TextStyle.Pretendard.body2
        messageLabel.textColor = .Feelter.gray0
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.padding = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        messageLabel.setContentHuggingPriority(.required, for: .vertical)

        readCountLabel.font = TextStyle.Pretendard.caption2
        readCountLabel.textColor = .Feelter.gray60
        readCountLabel.textAlignment = .right
        readCountLabel.isHidden = true

        timeStackView.axis = .vertical
        timeStackView.spacing = 2
        timeStackView.alignment = .trailing

        timeLabel.font = TextStyle.Pretendard.caption1
        timeLabel.textColor = .Feelter.gray60

        statusLabel.font = TextStyle.Pretendard.caption2
        statusLabel.textColor = .Feelter.gray60

        statusIconImageView.contentMode = .scaleAspectFit
        statusIconImageView.tintColor = .Feelter.gray60
        statusIconImageView.isHidden = true

        retryButton.tintColor = .Feelter.gray60
        retryButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        retryButton.setTitle(nil, for: .normal)
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)

        statusStackView.axis = .horizontal
        statusStackView.spacing = 4
        statusStackView.alignment = .center

        horizontalStackView.axis = .horizontal
        horizontalStackView.alignment = .bottom
        horizontalStackView.spacing = Layout.stackSpacing
    }

    private func configureMessageContent(text: String?, images: [ChatImageSource]) {
        // 텍스트가 있고, 공백이 아닌 실제 내용이 있을 때만 표시
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        timeStackView.isHidden = !showsTime
    }

    private func configureStatus(for status: MessageSendStatus, showsTime: Bool, isOutgoing: Bool) {
        let shouldShowStatus = showsTime && status != .sent
        statusStackView.isHidden = !shouldShowStatus

        statusLabel.text = nil
        statusLabel.isHidden = true
        statusIconImageView.isHidden = true
        retryButton.isHidden = true

        switch status {
        case .sending:
            statusIconImageView.image = UIImage.Icon.message
            statusIconImageView.isHidden = !shouldShowStatus
        case .failed:
            retryButton.isHidden = !shouldShowStatus
            retryButton.tintColor = .systemRed
        case .sent:
            break
        }

        let shouldShowReadCount = isOutgoing && showsTime && status == .sent
        readCountLabel.text = shouldShowReadCount ? "1" : nil
        readCountLabel.isHidden = !shouldShowReadCount
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 이제 고정 너비로 계산하므로 동적 업데이트 불필요
        // updateBubbleMaxWidth()
    }

    private func updateBubbleMaxWidth() {
        guard bubbleMaxWidthConstraint != nil else { return }
        let horizontalWidth = horizontalStackView.bounds.width
        guard horizontalWidth > 0 else { return }

        let visibleSubviews = horizontalStackView.arrangedSubviews.filter { !$0.isHidden }
        let spacingCount = max(visibleSubviews.count - 1, 0)
        let totalSpacing = CGFloat(spacingCount) * Layout.stackSpacing

        let profileWidth = currentIsOutgoing ? 0 : profileImageView.bounds.width
        let timeWidth = timeStackView.isHidden
            ? 0
            : timeStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        let statusWidth = (currentIsOutgoing && !statusStackView.isHidden)
            ? statusStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
            : 0
        let fixedWidth = profileWidth + timeWidth + statusWidth

        let maxWidth = max(0, horizontalWidth - fixedWidth - totalSpacing)
        let offset = maxWidth - horizontalWidth
        bubbleMaxWidthConstraint?.update(offset: offset)
    }

    private func configureLayoutDirection(isOutgoing: Bool) {
        horizontalStackView.arrangedSubviews.forEach { view in
            horizontalStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        bubbleMaxWidthConstraint?.deactivate()
        bubbleMaxWidthConstraint = nil

        // 프로필 이미지는 스택뷰에 추가하지 않고 visibility만 조절
        profileImageView.isHidden = isOutgoing

        // horizontalStackView의 leading 제약조건 업데이트
        horizontalStackView.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4).priority(.high)
            make.trailing.equalToSuperview().inset(16)
            if isOutgoing {
                make.leading.equalToSuperview().inset(16)
            } else {
                // 프로필 이미지 오른쪽에 위치
                make.leading.equalTo(profileImageView.snp.trailing).offset(Layout.stackSpacing)
            }
        }

        if isOutgoing {
            horizontalStackView.addArrangedSubview(spacerView)
            horizontalStackView.addArrangedSubview(statusStackView)
            horizontalStackView.addArrangedSubview(timeStackView)
            horizontalStackView.addArrangedSubview(bubbleContainerView)
        } else {
            horizontalStackView.addArrangedSubview(bubbleContainerView)
            horizontalStackView.addArrangedSubview(timeStackView)
            horizontalStackView.addArrangedSubview(spacerView)
        }

        // 버블 최대 너비 계산: 화면 너비 - 프로필/시간/상태 등 고정 요소 너비
        let screenWidth = UIScreen.main.bounds.width
        let horizontalInset: CGFloat = 16 * 2  // 좌우 inset
        let stackSpacing: CGFloat = Layout.stackSpacing

        // 고정 요소들의 너비 계산
        let profileWidth: CGFloat = isOutgoing ? 0 : (Layout.profileSize + stackSpacing)
        let timeWidth: CGFloat = 60 + stackSpacing  // 시간 레이블 예상 너비
        let statusWidth: CGFloat = isOutgoing ? (30 + stackSpacing) : 0  // 재전송 버튼/상태 아이콘

        let maxBubbleWidth = screenWidth - horizontalInset - profileWidth - timeWidth - statusWidth

        bubbleContainerView.snp.makeConstraints { make in
            bubbleMaxWidthConstraint = make.width.lessThanOrEqualTo(maxBubbleWidth).constraint
        }

        timeStackView.alignment = isOutgoing ? .trailing : .leading
        timeLabel.textAlignment = isOutgoing ? .right : .left
        readCountLabel.textAlignment = isOutgoing ? .right : .left

        timeStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeStackView.setContentHuggingPriority(.required, for: .horizontal)
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
