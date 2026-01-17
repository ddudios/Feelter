//
//  ChatRoomCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import UIKit
import SnapKit

final class ChatRoomCell: UITableViewCell {

    private enum Layout {
        static let profileSize: CGFloat = 52
        static let horizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 16
        static let contentSpacing: CGFloat = 12
        static let stackSpacing: CGFloat = 6
        static let badgeHorizontalPadding: CGFloat = 6
        static let badgeVerticalPadding: CGFloat = 3
    }

    private let profileImageView = UIImageView()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let messageLabel = UILabel()
    private let unreadBadgeLabel = CapsuleLabel(
        padding: UIEdgeInsets(
            top: Layout.badgeVerticalPadding,
            left: Layout.badgeHorizontalPadding,
            bottom: Layout.badgeVerticalPadding,
            right: Layout.badgeHorizontalPadding
        )
    )

    private let headerStackView = UIStackView()
    private let footerStackView = UIStackView()
    private let textStackView = UIStackView()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()

    private static let yearMonthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.M.d"
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
        profileImageView.image = UIImage(named: "appIcon")
        nameLabel.text = nil
        timeLabel.text = nil
        messageLabel.text = nil
        unreadBadgeLabel.isHidden = true
    }

    func configure(with chatRoom: ChatRoom, currentUserId: String?, unreadCount: Int = 0) {
        nameLabel.text = chatRoom.opponent.nick
        messageLabel.text = chatRoom.lastMessagePreview
        timeLabel.text = formattedTimestamp(from: chatRoom.updatedAt)


        // 개선된 hasUnreadMessage 메서드 사용 (내가 보낸 메시지는 배지 안 붙음)
        let hasUnread = chatRoom.hasUnreadMessage(currentUserId: currentUserId)
        unreadBadgeLabel.isHidden = !hasUnread

        // 읽지 않은 메시지 개수 표시
        if hasUnread {
            if unreadCount > 0 {
                // 개수가 있으면 숫자로 표시
                unreadBadgeLabel.text = unreadCount > 99 ? "99+" : "\(unreadCount)"
            } else {
                // 개수 정보가 없으면 "N"으로 표시
                unreadBadgeLabel.text = "N"
            }
        } else {
        }

        profileImageView.image = UIImage(named: "appIcon")
        if chatRoom.opponent.hasProfileImage {
            profileImageView.setFeelterImage(with: chatRoom.opponent.profileImage)
        }
    }

    private func configureHierarchy() {
        contentView.addSubview(profileImageView)
        contentView.addSubview(textStackView)
    }

    private func configureLayout() {
        profileImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.profileSize)
        }

        textStackView.snp.makeConstraints { make in
            make.leading.equalTo(profileImageView.snp.trailing).offset(Layout.contentSpacing)
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.top.bottom.equalToSuperview().inset(Layout.verticalInset)
        }
    }

    private func configureView() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = Layout.profileSize / 2
        profileImageView.backgroundColor = .clear

        nameLabel.font = TextStyle.Pretendard.body1
        nameLabel.textColor = .Feelter.gray15
        nameLabel.numberOfLines = 1

        timeLabel.font = TextStyle.Pretendard.caption1
        timeLabel.textColor = .Feelter.gray60
        timeLabel.textAlignment = .right

        messageLabel.font = TextStyle.Pretendard.body2
        messageLabel.textColor = .Feelter.gray75
        messageLabel.numberOfLines = 1
        messageLabel.lineBreakMode = .byTruncatingTail

        unreadBadgeLabel.font = TextStyle.Pretendard.semibold1
        unreadBadgeLabel.textColor = .Feelter.gray0
        unreadBadgeLabel.backgroundColor = .systemRed
        unreadBadgeLabel.isHidden = true

        headerStackView.axis = .horizontal
        headerStackView.alignment = .center
        headerStackView.spacing = Layout.stackSpacing
        headerStackView.addArrangedSubview(nameLabel)
        headerStackView.addArrangedSubview(timeLabel)

        footerStackView.axis = .horizontal
        footerStackView.alignment = .center
        footerStackView.spacing = Layout.stackSpacing
        footerStackView.addArrangedSubview(messageLabel)
        footerStackView.addArrangedSubview(unreadBadgeLabel)

        textStackView.axis = .vertical
        textStackView.spacing = Layout.stackSpacing
        textStackView.addArrangedSubview(headerStackView)
        textStackView.addArrangedSubview(footerStackView)

        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        unreadBadgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        messageLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        unreadBadgeLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func formattedTimestamp(from date: Date, referenceDate: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "어제"
        }
        let dateYear = calendar.component(.year, from: date)
        let referenceYear = calendar.component(.year, from: referenceDate)
        if dateYear == referenceYear {
            return Self.monthDayFormatter.string(from: date)
        }
        return Self.yearMonthDayFormatter.string(from: date)
    }
}
