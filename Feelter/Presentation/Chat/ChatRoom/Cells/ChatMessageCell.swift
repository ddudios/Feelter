//
//  ChatMessageCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import UIKit
import SnapKit

/// 파일 첨부 정보
struct ChatFileAttachment {
    let fileName: String
    let fileURL: String
    let mimeType: String

    /// 파일 확장자 기반 아이콘 이름 반환
    var iconName: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif":
            return "photo.fill"
        default:
            return "doc.fill"
        }
    }

    /// MIME 타입 판별
    static func mimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        default:
            return "application/octet-stream"
        }
    }
}

struct ChatMessageViewItem {
    let id: String
    let text: String?
    let images: [ChatImageSource]
    let files: [ChatFileAttachment]
    let date: Date
    let isOutgoing: Bool
    var status: MessageSendStatus
    var showsTime: Bool

    /// 파일 첨부가 있는지 여부 (이미지 제외 파일)
    var hasFiles: Bool {
        return !files.isEmpty
    }
}

enum ChatImageSource {
    case local(UIImage)
    case remote(String)
}

final class ChatMessageCell: UITableViewCell {

    var onRetryTapped: (() -> Void)?
    var onImageTapped: (([ChatImageSource], Int) -> Void)?  // (전체 이미지 목록, 탭한 이미지 인덱스)

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
    private let messageTextView = UITextView()  // UITextView로 변경
    private let textBubbleView = UIView()  // 텍스트 전용 버블
    private let imageGridView = ChatImageGridView()  // 이미지 그리드 (직접 사용)

    /// ✅ 이미지+텍스트일 때 시간을 텍스트 버블 옆에 배치하기 위한 컨테이너
    private lazy var textWithTimeContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Layout.stackSpacing
        stack.alignment = .bottom
        return stack
    }()

    private let timeLabel = UILabel()
    private let timeStackView = UIStackView()
    private let statusLabel = UILabel()
    private let statusIconImageView = UIImageView()
    private let retryButton = UIButton(type: .system)
    private let statusStackView = UIStackView()
    private let horizontalStackView = UIStackView()
    private let spacerView = UIView()
    private let textBubbleSpacerView = UIView()  // textWithTimeContainer용 spacer
    private var bubbleMaxWidthConstraint: Constraint?
    private var currentIsOutgoing = false
    private var hasImageAndText = false  // 이미지와 텍스트가 함께 있는지

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
        onImageTapped = nil
        currentIsOutgoing = false
        hasImageAndText = false
        messageTextView.text = nil
        timeLabel.text = nil
        statusLabel.text = nil
        statusIconImageView.image = nil
        retryButton.isHidden = true

        // ✅ 이미지 그리드 완전 초기화 (이전 콜백 무효화)
        imageGridView.reset()

        // 텍스트 버블 제약조건 초기화 (재사용 시 이전 제약 제거)
        textBubbleView.snp.removeConstraints()
    }

    func configure(with item: ChatMessageViewItem, opponentProfileImagePath: String?) {
        currentIsOutgoing = item.isOutgoing
        configureMessageContent(text: item.text, images: item.images)
        configureTextWithTimeLayout(isOutgoing: item.isOutgoing)
        configureTimeLabel(date: item.date, showsTime: item.showsTime, status: item.status)
        configureStatus(for: item.status, showsTime: item.showsTime, isOutgoing: item.isOutgoing)
        configureLayoutDirection(isOutgoing: item.isOutgoing)
        configureColors(isOutgoing: item.isOutgoing)

        // 이미지 탭 제스처 연결
        imageGridView.onImageTapped = { [weak self] tappedIndex in
            self?.onImageTapped?(item.images, tappedIndex)
        }

        // ✅ 이미지 로딩 완료 시 TableView에 높이 재계산 요청
        imageGridView.onImageLoadingCompleted = { [weak self] in
            guard let self = self else { return }

            // TableView를 찾아서 beginUpdates/endUpdates 호출 (높이 재계산)
            var view: UIView? = self.superview
            while view != nil {
                if let tableView = view as? UITableView {
                    guard tableView.window != nil else { break }
                    let contentHeight = tableView.contentSize.height
                    let scrollViewHeight = tableView.bounds.height
                    let contentOffsetY = tableView.contentOffset.y
                    let bottomInset = tableView.adjustedContentInset.bottom
                    let isNearBottom = contentOffsetY + scrollViewHeight + bottomInset >= contentHeight - 50
                    UIView.performWithoutAnimation {
                        tableView.beginUpdates()
                        tableView.endUpdates()
                    }
                    if isNearBottom, tableView.numberOfSections > 0 {
                        let lastSection = tableView.numberOfSections - 1
                        let lastRow = tableView.numberOfRows(inSection: lastSection) - 1
                        if lastRow >= 0 {
                            let indexPath = IndexPath(row: lastRow, section: lastSection)
                            tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
                        }
                    }
                    break
                }
                view = view?.superview
            }
        }

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

        // 텍스트 버블 (색상 있음)
        textBubbleView.addSubview(messageTextView)

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

        // 텍스트 뷰 레이아웃
        messageTextView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        statusIconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.statusIconSize)
        }

        retryButton.snp.makeConstraints { make in
            make.width.height.equalTo(13)
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

        bubbleContainerView.layer.cornerRadius = 0  // 컨테이너는 투명
        bubbleContainerView.clipsToBounds = false
        bubbleContainerView.backgroundColor = .clear
        bubbleContainerView.isUserInteractionEnabled = true  // 터치 이벤트 전달 허용
        bubbleContainerView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        bubbleContainerView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        bubbleStackView.axis = .vertical
        bubbleStackView.spacing = Layout.bubbleSpacing
        bubbleStackView.isUserInteractionEnabled = true  // 터치 이벤트 전달 허용
        // alignment는 configureLayoutDirection에서 동적으로 설정

        // 이미지 그리드 뷰 (둥근 모서리)
        imageGridView.layer.cornerRadius = Layout.bubbleCornerRadius
        imageGridView.clipsToBounds = true
        imageGridView.backgroundColor = .clear

        // 텍스트 버블 (색상 있음, 둥근 모서리)
        textBubbleView.layer.cornerRadius = Layout.bubbleCornerRadius
        textBubbleView.clipsToBounds = true
        textBubbleView.isUserInteractionEnabled = true  // 터치 이벤트 전달 허용
        textBubbleView.setContentHuggingPriority(.required, for: .horizontal)  // 텍스트 길이에 맞춤
        textBubbleView.setContentCompressionResistancePriority(.required, for: .horizontal)

        // UITextView 설정 (복사 가능)
        messageTextView.font = TextStyle.Pretendard.body2
        messageTextView.textColor = .Feelter.gray0
        messageTextView.backgroundColor = .clear
        messageTextView.isEditable = false
        messageTextView.isSelectable = true
        messageTextView.isUserInteractionEnabled = true  // 터치 및 제스처 활성화
        messageTextView.isScrollEnabled = false
        messageTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        messageTextView.textContainer.lineFragmentPadding = 4
        messageTextView.setContentCompressionResistancePriority(.required, for: .vertical)
        messageTextView.setContentHuggingPriority(.required, for: .vertical)
        messageTextView.setContentCompressionResistancePriority(.required, for: .horizontal)
        messageTextView.setContentHuggingPriority(.required, for: .horizontal)

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
        let hasText = text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasImages = !images.isEmpty

        // 이미지와 텍스트가 함께 있는지 확인
        hasImageAndText = hasText && hasImages


        // 기존 배치 초기화
        bubbleStackView.arrangedSubviews.forEach {
            bubbleStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        textWithTimeContainer.isHidden = !hasImageAndText

        if hasText, let text = text {
            messageTextView.text = text
            textBubbleView.isHidden = false
        } else {
            messageTextView.text = nil
            textBubbleView.isHidden = true
        }

        if hasImages {
            imageGridView.isHidden = false
            imageGridView.configure(with: images)
        } else {
            imageGridView.isHidden = true
        }

        // 레이아웃 재구성
        if hasImageAndText {
            // 이미지 + 텍스트: 세로로 배치 (텍스트+시간은 하단 행)
            bubbleStackView.addArrangedSubview(imageGridView)
            bubbleStackView.addArrangedSubview(textWithTimeContainer)
        } else if hasImages {
            // 이미지만
            bubbleStackView.addArrangedSubview(imageGridView)
        } else if hasText {
            // 텍스트만
            bubbleStackView.addArrangedSubview(textBubbleView)
        }
    }

    private func configureTextWithTimeLayout(isOutgoing: Bool) {
        // 이미지+텍스트일 때 텍스트 버블 너비 제한
        guard hasImageAndText else { return }

        // 화면 너비 기반 계산
        let screenWidth = UIScreen.main.bounds.width
        let horizontalInset: CGFloat = 16 * 2  // 좌우 inset
        let stackSpacing: CGFloat = Layout.stackSpacing

        // 고정 요소 너비 (이미지+텍스트는 시간/상태를 컨테이너 내부에 배치)
        let profileWidth: CGFloat = isOutgoing ? 0 : (Layout.profileSize + stackSpacing)
        let bubbleMaxWidth = screenWidth - horizontalInset - profileWidth

        let timeWidth: CGFloat = 60 + stackSpacing  // 시간 레이블 예상 너비
        let statusWidth: CGFloat = isOutgoing ? (30 + stackSpacing) : 0  // 재전송 버튼/상태 아이콘
        let maxTextBubbleWidth = max(0, bubbleMaxWidth - timeWidth - statusWidth)

        textBubbleView.snp.remakeConstraints { make in
            make.width.lessThanOrEqualTo(maxTextBubbleWidth).priority(.required)
        }

    }

    private func configureTextWithTimeContainer(isOutgoing: Bool) {
        resetTextWithTimeContainer()

        statusStackView.removeFromSuperview()
        timeStackView.removeFromSuperview()
        textBubbleView.removeFromSuperview()

        if isOutgoing {
            textWithTimeContainer.addArrangedSubview(statusStackView)
            textWithTimeContainer.addArrangedSubview(timeStackView)
            textWithTimeContainer.addArrangedSubview(textBubbleView)
        } else {
            textWithTimeContainer.addArrangedSubview(textBubbleView)
            textWithTimeContainer.addArrangedSubview(timeStackView)
        }
    }

    private func resetTextWithTimeContainer() {
        textWithTimeContainer.arrangedSubviews.forEach { view in
            textWithTimeContainer.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func configureTimeLabel(date: Date, showsTime: Bool, status: MessageSendStatus) {
        // failed 상태일 때는 시간을 완전히 숨김
        if status == .failed {
            timeLabel.isHidden = true
            timeStackView.isHidden = true
        } else {
            timeLabel.text = Self.timeFormatter.string(from: date)
            timeLabel.isHidden = !showsTime
            timeStackView.isHidden = !showsTime
        }
    }

    private func configureStatus(for status: MessageSendStatus, showsTime: Bool, isOutgoing: Bool) {
        // failed 상태일 때는 showsTime과 관계없이 항상 재전송 버튼 표시
        let shouldShowStatus: Bool
        if status == .failed {
            shouldShowStatus = true  // 항상 표시
        } else {
            shouldShowStatus = showsTime && status != .sent
        }

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

        // 텍스트 버블 정렬 (보내는 메시지는 오른쪽, 받는 메시지는 왼쪽)
        bubbleStackView.alignment = isOutgoing ? .trailing : .leading

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

        if hasImageAndText {
            configureTextWithTimeContainer(isOutgoing: isOutgoing)
            if isOutgoing {
                // 보내는 메시지 (이미지+텍스트): [spacer] [bubble]
                horizontalStackView.addArrangedSubview(spacerView)
                horizontalStackView.addArrangedSubview(bubbleContainerView)
            } else {
                // 받는 메시지 (이미지+텍스트): [bubble] [spacer]
                horizontalStackView.addArrangedSubview(bubbleContainerView)
                horizontalStackView.addArrangedSubview(spacerView)
            }
        } else if isOutgoing {
            resetTextWithTimeContainer()
            // 보내는 메시지: [spacer] [status] [time] [bubble]
            horizontalStackView.addArrangedSubview(spacerView)
            horizontalStackView.addArrangedSubview(statusStackView)
            horizontalStackView.addArrangedSubview(timeStackView)
            horizontalStackView.addArrangedSubview(bubbleContainerView)
        } else {
            resetTextWithTimeContainer()
            // 받는 메시지: [bubble] [time] [spacer]
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
        let timeWidth: CGFloat = hasImageAndText ? 0 : (60 + stackSpacing)  // 시간 레이블 예상 너비
        let statusWidth: CGFloat = (isOutgoing && !hasImageAndText) ? (30 + stackSpacing) : 0  // 재전송 버튼/상태 아이콘

        let maxBubbleWidth = screenWidth - horizontalInset - profileWidth - timeWidth - statusWidth

        bubbleContainerView.snp.makeConstraints { make in
            bubbleMaxWidthConstraint = make.width.lessThanOrEqualTo(maxBubbleWidth).constraint
        }

        timeStackView.alignment = isOutgoing ? .trailing : .leading
        timeLabel.textAlignment = isOutgoing ? .right : .left

        timeStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeStackView.setContentHuggingPriority(.required, for: .horizontal)
        statusStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusStackView.setContentHuggingPriority(.required, for: .horizontal)
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func configureColors(isOutgoing: Bool) {
        // 텍스트 버블만 색상 적용 (이미지 버블은 항상 투명)
        textBubbleView.backgroundColor = isOutgoing ? .Feelter.brightTurquoise : .Feelter.deepTurquoise
    }

    @objc private func retryButtonTapped() {
        onRetryTapped?()
    }

    /// hitTest 오버라이드: 터치가 실제 텍스트 콘텐츠 위에 있을 때만 messageTextView를 반환
    /// UITextView는 padding이 있어서 bounds보다 더 정확한 터치 감지가 필요
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // messageTextView가 숨겨져 있지 않고, 사용 가능한 경우
        if !messageTextView.isHidden,
           messageTextView.isUserInteractionEnabled,
           !textBubbleView.isHidden,
           messageTextView.text?.isEmpty == false {

            // contentView 기준 point를 messageTextView 기준으로 변환
            let textViewPoint = messageTextView.convert(point, from: self)

            // 먼저 bounds 체크
            guard messageTextView.bounds.contains(textViewPoint) else {
                return super.hitTest(point, with: event)
            }

            // textContainer 기준으로 변환 (inset 고려)
            var containerPoint = textViewPoint
            containerPoint.x -= messageTextView.textContainerInset.left
            containerPoint.y -= messageTextView.textContainerInset.top

            // layoutManager를 사용하여 실제 텍스트 영역인지 확인
            let layoutManager = messageTextView.layoutManager
            let textContainer = messageTextView.textContainer

            // 텍스트가 있는 실제 영역의 bounding rect 계산
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            // 약간의 여유 공간 추가 (탭하기 쉽게)
            let expandedRect = boundingRect.insetBy(dx: -8, dy: -8)

            // 터치가 실제 텍스트 영역 내에 있는지 확인
            if expandedRect.contains(containerPoint) {
                return messageTextView
            } else {
            }
        }

        // 그 외의 경우 기본 동작
        return super.hitTest(point, with: event)
    }
}
