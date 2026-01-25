//
//  SubtitleCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/25/26.
//

import UIKit
import SnapKit

final class SubtitleCell: UITableViewCell {

    // MARK: - UI Components

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .Feelter.brightTurquoise
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body2
        label.textColor = .Feelter.gray30
        label.numberOfLines = 0
        return label
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 8
        return view
    }()

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(timeLabel)
        containerView.addSubview(subtitleLabel)

        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4)
            make.leading.trailing.equalToSuperview()
        }

        timeLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalTo(subtitleLabel.snp.centerY)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(timeLabel.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
        }
    }

    // MARK: - Configuration

    func configure(with item: SubtitleItem, isHighlighted: Bool) {
        timeLabel.text = formatTime(item.startTime)
        subtitleLabel.text = item.text

        if isHighlighted {
            containerView.backgroundColor = .Feelter.blackTurquoise
            subtitleLabel.textColor = .Feelter.gray30
        } else {
            containerView.backgroundColor = .clear
            subtitleLabel.textColor = .Feelter.gray30
        }
    }

    // MARK: - Helper

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
