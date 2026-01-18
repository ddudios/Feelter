//
//  CommentCell.swift
//  Feelter
//
//  Created by Claude on 1/19/26.
//

import UIKit
import SnapKit

final class CommentCell: UITableViewCell {

    var onMoreTapped: ((UIView) -> Void)?

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let verticalInset: CGFloat = 12
        static let profileSize: CGFloat = 32
        static let moreButtonSize: CGFloat = 20
        static let spacing: CGFloat = 8
    }

    private let profileImageView = UIImageView()
    private let nicknameLabel = UILabel()
    private let timeLabel = UILabel()
    private let contentLabel = UILabel()
    private let moreButton = UIButton(type: .system)

    private var currentCommentId: String?

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
        currentCommentId = nil
        profileImageView.image = UIImage(named: "appIcon")
        nicknameLabel.text = nil
        timeLabel.text = nil
        contentLabel.text = nil
        moreButton.isHidden = true
        onMoreTapped = nil
    }

    func configure(with comment: Comment, isOwnedByCurrentUser: Bool) {
        currentCommentId = comment.id

        profileImageView.image = UIImage(named: "appIcon")
        if let path = comment.writer.profileImageURL, !path.isEmpty {
            profileImageView.setFeelterImage(with: path)
        }

        let nickname = comment.writer.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = comment.writer.name.trimmingCharacters(in: .whitespacesAndNewlines)
        nicknameLabel.text = nickname.isEmpty ? name : nickname

        timeLabel.text = comment.createdAt.relativeDescription()
        contentLabel.text = comment.content
        moreButton.isHidden = !isOwnedByCurrentUser
        moreButton.isUserInteractionEnabled = isOwnedByCurrentUser
    }

    private func configureHierarchy() {
        contentView.addSubview(profileImageView)
        contentView.addSubview(nicknameLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(moreButton)
        contentView.addSubview(contentLabel)
    }

    private func configureLayout() {
        profileImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Layout.verticalInset)
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.size.equalTo(Layout.profileSize)
        }

        nicknameLabel.snp.makeConstraints { make in
            make.top.equalTo(profileImageView)
            make.leading.equalTo(profileImageView.snp.trailing).offset(Layout.spacing)
        }

        timeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(nicknameLabel)
            make.leading.equalTo(nicknameLabel.snp.trailing).offset(Layout.spacing)
        }

        moreButton.snp.makeConstraints { make in
            make.centerY.equalTo(nicknameLabel)
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.size.equalTo(Layout.moreButtonSize)
        }

        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(nicknameLabel.snp.bottom).offset(4)
            make.leading.equalTo(profileImageView.snp.trailing).offset(Layout.spacing)
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().inset(Layout.verticalInset)
        }
    }

    private func configureView() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = Layout.profileSize / 2
        profileImageView.layer.borderWidth = 1
        profileImageView.layer.borderColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5).cgColor
        profileImageView.backgroundColor = .Feelter.gray100

        nicknameLabel.font = TextStyle.Pretendard.caption1
        nicknameLabel.textColor = .Feelter.gray15

        timeLabel.font = TextStyle.Pretendard.caption2
        timeLabel.textColor = .Feelter.gray75

        contentLabel.font = TextStyle.Pretendard.body2
        contentLabel.textColor = .Feelter.gray30
        contentLabel.numberOfLines = 0

        moreButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreButton.tintColor = .Feelter.gray45
        moreButton.isHidden = true
        moreButton.addTarget(self, action: #selector(moreButtonTapped), for: .touchUpInside)
    }

    @objc private func moreButtonTapped() {
        onMoreTapped?(moreButton)
    }
}
