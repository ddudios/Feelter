//
//  TopRankingCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import UIKit
import SnapKit
import Kingfisher

final class TopRankingCell: BaseCollectionViewCell {
    
    var onTap: (() -> Void)?

    // MARK: - Layout Constants
    private enum Layout {
        static let cardTopInset: CGFloat = 10
        static let imageSize: CGFloat = 200
        static let labelTopSpacing: CGFloat = 12
        static let titleTopSpacing: CGFloat = 6
        static let categoryTopSpacing: CGFloat = 8
        static let labelHorizontalInset: CGFloat = 20
        static let rankBadgeDiameter: CGFloat = 44
        static let rankBadgeBorderWidth: CGFloat = 2
        static let cardBottomInset: CGFloat = rankBadgeDiameter / 2
    }

    // MARK: - UI Components
    private let cardView = {
        let view = UIView()
        view.backgroundColor = .Feelter.blackTurquoise
        view.layer.borderColor = UIColor.Feelter.deepTurquoise?.cgColor
        view.layer.borderWidth = 2
        view.clipsToBounds = true
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let filterImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .Feelter.deepTurquoise
        return imageView
    }()

    private let creatorNameLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.semibold1
        label.textColor = .Feelter.gray75
        label.textAlignment = .center
        return label
    }()

    private let titleLabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .Feelter.gray30
        label.textAlignment = .center
        label.numberOfLines = 4
        return label
    }()

    private let categoryLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.title2
        label.textColor = .Feelter.gray75
        label.textAlignment = .center
        return label
    }()

    private let rankBadgeView = {
        let view = UIView()
        view.backgroundColor = .Feelter.blackTurquoise
        view.layer.borderWidth = Layout.rankBadgeBorderWidth
        view.layer.borderColor = UIColor.Feelter.deepTurquoise?.cgColor
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()

    private let rankLabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .Feelter.brightTurquoise
        label.textAlignment = .center
        return label
    }()

    override func configureView() {
        super.configureView()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)
    }

    // MARK: - Configuration
    override func configureHierarchy() {
        contentView.addSubview(cardView)
        cardView.addSubview(filterImageView)
        cardView.addSubview(creatorNameLabel)
        cardView.addSubview(titleLabel)
        cardView.addSubview(categoryLabel)

        // 뱃지는 카드 위에 떠야 하므로 마지막에 add
        contentView.addSubview(rankBadgeView)
        rankBadgeView.addSubview(rankLabel)
    }

    override func configureLayout() {
        cardView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-Layout.cardBottomInset)
        }

        filterImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.cardTopInset)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.imageSize)
        }

        creatorNameLabel.snp.makeConstraints { make in
            make.top.equalTo(filterImageView.snp.bottom).offset(Layout.labelTopSpacing)
            make.centerX.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(creatorNameLabel.snp.bottom).offset(Layout.titleTopSpacing)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Layout.labelHorizontalInset)
            make.trailing.lessThanOrEqualToSuperview().offset(-Layout.labelHorizontalInset)
        }

        categoryLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.categoryTopSpacing)
            make.centerX.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview().offset(-Layout.cardTopInset)
        }

        rankBadgeView.snp.makeConstraints { make in
            make.centerX.equalTo(cardView.snp.centerX)
            make.centerY.equalTo(cardView.snp.bottom)
            make.width.height.equalTo(Layout.rankBadgeDiameter)
        }

        rankLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    // MARK: - Layout Lifecycle (✨ 해결의 핵심)
    override func layoutSubviews() {
        super.layoutSubviews()

        // 1. 제약조건을 강제로 프레임으로 변환 (타이밍 문제 해결 1차)
        contentView.layoutIfNeeded()

        // 2. Corner Radius 적용
        applyCornerRadius()

        // 3. (안전장치) 아주 가끔 layoutIfNeeded로도 프레임이 안 잡히는 첫 로딩 순간을 위해
        //    다음 런루프에서 한 번 더 적용 (타이밍 문제 해결 2차)
        DispatchQueue.main.async { [weak self] in
            self?.applyCornerRadius()
        }
    }

    private func applyCornerRadius() {
        // [고정 크기 뷰] bounds 계산 필요 없음 -> 상수로 박아버려서 무조건 원형 보장
        filterImageView.layer.cornerRadius = Layout.imageSize / 2
        rankBadgeView.layer.cornerRadius = Layout.rankBadgeDiameter / 2

        // [가변 크기 뷰] layoutIfNeeded() 덕분에 올바른 width를 가져옴
        // 혹시라도 width가 0이면 0이 들어가겠지만, DispatchQueue가 곧바로 다시 잡아줌
        if cardView.bounds.width > 0 {
            cardView.layer.cornerRadius = cardView.bounds.width / 2
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 재사용될 때 레이아웃 갱신 예약
        self.setNeedsLayout()
        filterImageView.image = nil
        onTap = nil
    }

    func configure(with filter: FilterSummary, rank: Int) {
        filterImageView.setFeelterImage(with: filter.mainImageURL)
        creatorNameLabel.text = filter.creator.nickname
        titleLabel.text = filter.title
        categoryLabel.text = "#\(filter.category.rawValue)"
        rankLabel.text = "\(rank)"
    }

    @objc private func handleTap() {
        onTap?()
    }
}
