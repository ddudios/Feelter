//
//  ChatDateSeparatorCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import UIKit
import SnapKit

final class ChatDateSeparatorCell: UITableViewCell {

    private let leftLineView = UIView()
    private let rightLineView = UIView()
    private let dateLabel = UILabel()
    private let containerStackView = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with dateText: String) {
        dateLabel.text = dateText
    }

    private func configureHierarchy() {
        contentView.addSubview(containerStackView)
        containerStackView.addArrangedSubview(leftLineView)
        containerStackView.addArrangedSubview(dateLabel)
        containerStackView.addArrangedSubview(rightLineView)
    }

    private func configureLayout() {
        containerStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }

        leftLineView.snp.makeConstraints { make in
            make.height.equalTo(1)
        }

        rightLineView.snp.makeConstraints { make in
            make.height.equalTo(1)
            make.width.equalTo(leftLineView)
        }
    }

    private func configureView() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        containerStackView.axis = .horizontal
        containerStackView.alignment = .center
        containerStackView.spacing = 12

        leftLineView.backgroundColor = .Feelter.gray90
        rightLineView.backgroundColor = .Feelter.gray90

        dateLabel.font = TextStyle.Pretendard.caption1
        dateLabel.textColor = .Feelter.gray60
        dateLabel.textAlignment = .center
    }
}
