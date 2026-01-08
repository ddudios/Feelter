//
//  TopRankingHeaderView.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import UIKit
import SnapKit

final class TopRankingHeaderView: UICollectionReusableView {

    static let identifier = String(describing: TopRankingHeaderView.self)

    private enum Layout {
        static let horizontalInset: CGFloat = Spacing.padding
        static let labelToStackSpacing: CGFloat = 10
        static let buttonHeight: CGFloat = 28
        static let buttonHorizontalPadding: CGFloat = 12
        static let buttonVerticalPadding: CGFloat = 6
        static let stackSpacing: CGFloat = 8
        static let topInset: CGFloat = 4
    }

    var onSortTypeSelected: ((FilterSortType) -> Void)?

    private let titleLabel = SectionTitleLabel(title: "Top Ranking")

    private lazy var sortButtonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .center
        stackView.spacing = Layout.stackSpacing
        return stackView
    }()

    private lazy var popularityButton = createSortButton(title: "인기순", sortType: .popularity)
    private lazy var purchaseButton = createSortButton(title: "구매순", sortType: .purchase)
    private lazy var latestButton = createSortButton(title: "최신순", sortType: .latest)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(sortType: FilterSortType) {
        updateSortButtons(selected: sortType)
    }

    private func configureHierarchy() {
        addSubview(titleLabel)
        addSubview(sortButtonStackView)
        sortButtonStackView.addArrangedSubview(popularityButton)
        sortButtonStackView.addArrangedSubview(purchaseButton)
        sortButtonStackView.addArrangedSubview(latestButton)
    }

    private func configureLayout() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.horizontalInset)
            make.top.equalToSuperview().offset(Layout.topInset)
        }

        sortButtonStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.labelToStackSpacing)
            make.height.equalTo(Layout.buttonHeight)
            make.leading.greaterThanOrEqualToSuperview().offset(Layout.horizontalInset)
            make.bottom.lessThanOrEqualToSuperview()
        }
    }

    private func configureView() {
        backgroundColor = .clear
    }

    private func createSortButton(title: String, sortType: FilterSortType) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.layer.cornerRadius = Layout.buttonHeight / 2
        button.contentEdgeInsets = UIEdgeInsets(
            top: Layout.buttonVerticalPadding,
            left: Layout.buttonHorizontalPadding,
            bottom: Layout.buttonVerticalPadding,
            right: Layout.buttonHorizontalPadding
        )
        button.snp.makeConstraints { make in
            make.height.equalTo(Layout.buttonHeight)
        }
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        button.addAction(UIAction { [weak self] _ in
            self?.sortButtonTapped(sortType)
        }, for: .touchUpInside)

        return button
    }

    private func sortButtonTapped(_ sortType: FilterSortType) {
        updateSortButtons(selected: sortType)
        onSortTypeSelected?(sortType)
    }

    private func updateSortButtons(selected sortType: FilterSortType) {
        updateSortButtonStyle(popularityButton, isSelected: sortType == .popularity)
        updateSortButtonStyle(purchaseButton, isSelected: sortType == .purchase)
        updateSortButtonStyle(latestButton, isSelected: sortType == .latest)
    }

    private func updateSortButtonStyle(_ button: UIButton, isSelected: Bool) {
        if isSelected {
            button.backgroundColor = .Feelter.brightTurquoise
            button.titleLabel?.font = TextStyle.Pretendard.title2
            button.setTitleColor(.Feelter.gray0, for: .normal)
        } else {
            button.backgroundColor = .Feelter.blackTurquoise
            button.titleLabel?.font = TextStyle.Pretendard.body2
            button.setTitleColor(.Feelter.gray75, for: .normal)
        }
    }
}
