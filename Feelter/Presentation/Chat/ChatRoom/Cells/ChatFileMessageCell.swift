//
//  ChatFileMessageCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/14/26.
//

import UIKit
import SnapKit

final class ChatFileMessageCell: UITableViewCell {

    // MARK: - Callback

    /// 버블 탭 시 실행되는 클로저
    var onFileTapped: (() -> Void)?

    // MARK: - Layout Constants

    private enum Layout {
        static let profileSize: CGFloat = 36
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 4
        static let elementSpacing: CGFloat = 8
        static let bubbleCornerRadius: CGFloat = 12
        static let bubblePadding: CGFloat = 12
        static let maxBubbleWidthRatio: CGFloat = 0.65
        static let fileIconSize: CGFloat = 30
    }

    // MARK: - UI Components

    /// 상대방 프로필 이미지 (Incoming만 표시)
    private let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Layout.profileSize / 2
        imageView.backgroundColor = .clear
        return imageView
    }()

    /// 파일 정보를 담는 버블
    private let bubbleContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = Layout.bubbleCornerRadius
        view.clipsToBounds = true
        return view
    }()

    /// 버블 내부 가로 스택뷰 (좌측: 텍스트, 우측: 아이콘)
    private let bubbleContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.distribution = .fill
        return stackView
    }()

    /// 파일 아이콘 (우측)
    private let fileIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: "doc.text.fill")
        imageView.tintColor = .Feelter.brightTurquoise
        return imageView
    }()

    /// 파일명 라벨
    private let fileNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .black
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    /// 시간 라벨
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .Feelter.gray60
        return label
    }()

    /// 읽음 표시 라벨
    private let readCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10)
        label.textColor = .Feelter.gray0
        return label
    }()

    /// 시간 + 읽음 스택뷰
    private let timeStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .trailing
        stackView.spacing = 2
        return stackView
    }()

    // MARK: - Properties

    private var currentIsOutgoing = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureHierarchy()
        configureLayout()
        configureView()
        configureTapGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = nil
        fileNameLabel.text = nil
        timeLabel.text = nil
        readCountLabel.text = nil
        currentIsOutgoing = false
        onFileTapped = nil
    }

    // MARK: - Configuration

    func configure(
        with file: ChatFileAttachment,
        date: Date,
        isOutgoing: Bool,
        showsTime: Bool,
        opponentProfileImagePath: String?
    ) {
        currentIsOutgoing = isOutgoing

        
        fileNameLabel.text = file.fileName
        
        timeLabel.text = Self.timeFormatter.string(from: date)
        timeStackView.isHidden = !showsTime
        
        readCountLabel.text = isOutgoing ? "1" : nil
        readCountLabel.isHidden = !isOutgoing

        // 레이아웃 방향
        updateLayoutDirection(isOutgoing: isOutgoing)

        // 프로필 이미지 (수신만)
        if isOutgoing {
            profileImageView.image = nil
            profileImageView.isHidden = true
        } else {
            profileImageView.isHidden = false
            if let path = opponentProfileImagePath, !path.isEmpty {
                profileImageView.setFeelterImage(with: path)
            } else {
                profileImageView.image = UIImage(named: "appIcon")
            }
        }
    }

    // MARK: - Private Methods

    private func configureHierarchy() {
        contentView.addSubview(profileImageView)
        contentView.addSubview(bubbleContainerView)
        contentView.addSubview(timeStackView)

        // 버블 내부 구조
        bubbleContainerView.addSubview(bubbleContentStackView)

        // 버블 콘텐츠 스택 (좌: 텍스트, 우: 아이콘)
        bubbleContentStackView.addArrangedSubview(fileNameLabel)
        bubbleContentStackView.addArrangedSubview(fileIconImageView)

        // 시간 스택
        timeStackView.addArrangedSubview(readCountLabel)
        timeStackView.addArrangedSubview(timeLabel)
    }

    private func configureLayout() {
        // 프로필 이미지 (좌측 상단 고정)
        profileImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Layout.verticalPadding)
            make.leading.equalToSuperview().inset(Layout.horizontalPadding)
            make.width.height.equalTo(Layout.profileSize)
        }

        // 버블 내부 스택뷰
        bubbleContentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Layout.bubblePadding)
        }

        // 파일 아이콘 고정 크기
        fileIconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.fileIconSize)
        }

        // 텍스트 스택 우선순위 설정
        fileNameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        fileNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        fileIconImageView.setContentHuggingPriority(.required, for: .horizontal)
        fileIconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        // 초기 레이아웃 (수신 메시지 기본값)
        updateLayoutDirection(isOutgoing: false)
    }

    private func configureView() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    private func configureTapGesture() {
        // contentView에 제스처 추가 (bubbleContainerView만 추가하면 터치가 전달되지 않을 수 있음)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCellTap(_:)))
        tapGesture.cancelsTouchesInView = false
        contentView.addGestureRecognizer(tapGesture)
        contentView.isUserInteractionEnabled = true
        bubbleContainerView.isUserInteractionEnabled = true
    }

    @objc private func handleCellTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: bubbleContainerView)
        if bubbleContainerView.bounds.contains(location) {
            onFileTapped?()
        }
    }

    private func updateLayoutDirection(isOutgoing: Bool) {
        let maxBubbleWidth = UIScreen.main.bounds.width * Layout.maxBubbleWidthRatio

        // 기존 제약조건 제거
        bubbleContainerView.snp.removeConstraints()
        timeStackView.snp.removeConstraints()

        if isOutgoing {
            // 발신: 우측 정렬
            bubbleContainerView.snp.makeConstraints { make in
                make.top.equalToSuperview().inset(Layout.verticalPadding)
                make.bottom.equalToSuperview().inset(Layout.verticalPadding)
                make.trailing.equalToSuperview().inset(Layout.horizontalPadding)
                make.width.lessThanOrEqualTo(maxBubbleWidth)
            }
            timeStackView.snp.makeConstraints { make in
                make.trailing.equalTo(bubbleContainerView.snp.leading).offset(-Layout.elementSpacing)
                make.bottom.equalTo(bubbleContainerView.snp.bottom)
            }
            timeStackView.alignment = .trailing
        } else {
            // 수신: 좌측 정렬 (프로필 이미지 옆)
            bubbleContainerView.snp.makeConstraints { make in
                make.top.equalToSuperview().inset(Layout.verticalPadding)
                make.bottom.equalToSuperview().inset(Layout.verticalPadding)
                make.leading.equalTo(profileImageView.snp.trailing).offset(Layout.elementSpacing)
                make.width.lessThanOrEqualTo(maxBubbleWidth)
            }
            timeStackView.snp.makeConstraints { make in
                make.leading.equalTo(bubbleContainerView.snp.trailing).offset(Layout.elementSpacing)
                make.bottom.equalTo(bubbleContainerView.snp.bottom)
            }
            timeStackView.alignment = .leading
        }
    }
}
