//
//  TodayFilterCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import UIKit
import SnapKit
import Kingfisher

final class TodayFilterCell: BaseCollectionViewCell {

    var onCategoryTapped: ((FilterCategory) -> Void)?

    private let backgroundImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .Feelter.gray100
        return imageView
    }()
    
    private let gradientView = BottomGradientView()
    
    private let useFilterButton = {
        let button = UIButton()
        button.setTitle("사용해보기", for: .normal)
        button.setTitleColor(.Feelter.gray60, for: .normal)
        button.titleLabel?.font = TextStyle.Pretendard.body3
        button.backgroundColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5).cgColor
        return button
    }()
    
    private let sectionLabel = {
        let label = UILabel()
        label.text = "오늘의 필터 소개"
        label.font = TextStyle.Pretendard.body3
        label.textColor = .Feelter.gray60
        return label
    }()
    
    private let introduceLabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .Feelter.gray0
        label.numberOfLines = 0
        return label
    }()
    
    private let titleLabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()
    
    private let descriptionLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .Feelter.gray60
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var categoryStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }()
    
    // MARK: - Initializer
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        setupCategoryButtons()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    override func configureHierarchy() {
        contentView.addSubview(backgroundImageView)
        
        // 이미지가 로딩되기 전에도 그라데이션은 있어야 하므로 이미지 뷰 위에 얹음
        contentView.addSubview(gradientView)
        
        // 나머지 라벨들은 그라데이션 위에 보여야 하므로 그 뒤에 추가
        contentView.addSubview(useFilterButton)
        contentView.addSubview(sectionLabel)
        contentView.addSubview(introduceLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(categoryStackView)
    }
    
    override func configureLayout() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        gradientView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.6)
        }
        
        useFilterButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(65)
            make.trailing.equalToSuperview().inset(20)
            make.height.equalTo(28)
            make.width.equalTo(75)
        }
        
        sectionLabel.snp.makeConstraints { make in
            make.bottom.equalTo(introduceLabel.snp.top).offset(-8)
            make.leading.equalToSuperview().offset(20)
        }
        
        introduceLabel.snp.makeConstraints { make in
            make.bottom.equalTo(titleLabel.snp.top).offset(-8)
            make.leading.equalToSuperview().offset(20)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.bottom.equalTo(descriptionLabel.snp.top).offset(-30)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().inset(20)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.bottom.equalTo(categoryStackView.snp.top).offset(-40)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().inset(20)
        }
        
        categoryStackView.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
            make.size.equalTo(56)
        }
    }
    
    private func setupCategoryButtons() {
        let categories: [(title: String, icon: UIImage?, category: FilterCategory)] = [
            ("푸드", UIImage.Category.food, .food),
            ("인물", UIImage.Category.people, .portrait),
            ("풍경", UIImage.Category.landscape, .landscape),
            ("야경", UIImage.Category.night, .night),
            ("별", UIImage.Category.star, .star)
        ]

        categories.forEach { category in
            let button = createCategoryButton(
                title: category.title,
                icon: category.icon,
                category: category.category
            )
            categoryStackView.addArrangedSubview(button)
        }
    }
    
    private func createCategoryButton(
        title: String,
        icon: UIImage?,
        category: FilterCategory
    ) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5)
        containerView.layer.cornerRadius = 12

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(categoryButtonTapped(_:)))
        containerView.addGestureRecognizer(tapGesture)
        containerView.isUserInteractionEnabled = true
        containerView.tag = category.hashValue

        let iconImageView = UIImageView(image: icon)
        iconImageView.tintColor = .Feelter.gray60
        iconImageView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = title
        label.font = TextStyle.Pretendard.semibold1
        label.textColor = .Feelter.gray60
        label.textAlignment = .center

        containerView.addSubview(iconImageView)
        containerView.addSubview(label)

        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(5)
            make.size.equalTo(32)
        }

        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-5.5)
        }

        return containerView
    }

    @objc private func categoryButtonTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag else { return }

        let category: FilterCategory
        switch tag {
        case FilterCategory.food.hashValue: category = .food
        case FilterCategory.portrait.hashValue: category = .portrait
        case FilterCategory.landscape.hashValue: category = .landscape
        case FilterCategory.night.hashValue: category = .night
        case FilterCategory.star.hashValue: category = .star
        default: category = .food
        }

        onCategoryTapped?(category)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onCategoryTapped = nil
    }
    
    func configure(with filter: TodayFilter) {
        introduceLabel.text = filter.introduction
        titleLabel.text = filter.title
        descriptionLabel.text = filter.description
        backgroundImageView.setFeelterImage(with: filter.mainImageURL)
    }
}

