//
//  HotTrendCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import UIKit
import SnapKit
import Kingfisher

final class HotTrendCell: BaseCollectionViewCell {

    static let maximumDimmingAlpha: CGFloat = 0.75

    var onTap: ((FilterSummary) -> Void)?
    private var currentFilter: FilterSummary?

    // 배경 이미지
    private let imageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .clear
        return imageView
    }()

    // 어둡게 만드는 뷰 (alpha 조절)
    private let dimmingView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = HotTrendCell.maximumDimmingAlpha
        view.layer.cornerRadius = 8
        view.isUserInteractionEnabled = false  // 탭 제스처가 통과하도록
        return view
    }()

    // 좌상단 제목
    private let titleLabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.caption1
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    // 우하단 좋아요 컨테이너
    private let likeContainerView = {
        let view = UIView()
        return view
    }()

    private let heartImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "heart.fill")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let likeCountLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body4
        label.textColor = .white
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTapGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap() {
        if let filter = currentFilter {
            onTap?(filter)
        }
    }

    override func configureHierarchy() {
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(likeContainerView)
        contentView.addSubview(dimmingView)  // 가장 위에 오도록 마지막에 추가

        likeContainerView.addSubview(heartImageView)
        likeContainerView.addSubview(likeCountLabel)
    }

    override func configureLayout() {
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().inset(20)
        }

        likeContainerView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(16)
            make.trailing.equalToSuperview().inset(16)
            make.height.equalTo(20)
        }

        heartImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }

        likeCountLabel.snp.makeConstraints { make in
            make.leading.equalTo(heartImageView.snp.trailing).offset(4)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTap = nil
        currentFilter = nil
        imageView.image = nil
        dimmingView.alpha = Self.maximumDimmingAlpha
    }

    func configure(with filter: FilterSummary) {
        currentFilter = filter
        titleLabel.text = filter.title
        likeCountLabel.text = "\(filter.likeCount)"
        imageView.setFeelterImage(with: filter.mainImageURL)
        dimmingView.alpha = Self.maximumDimmingAlpha
    }

    // 외부에서 dimming alpha 조절
    func setDimming(alpha: CGFloat) {
        dimmingView.alpha = alpha
    }
}
