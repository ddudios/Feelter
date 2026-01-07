//
//  BannerCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import UIKit
import SnapKit
import Kingfisher

final class BannerCell: BaseCollectionViewCell {

    // 탭 이벤트 Closure
    var onTap: ((Banner) -> Void)?
    private var currentBanner: Banner?

    private let bannerImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 22
        imageView.backgroundColor = .Feelter.gray100
        imageView.isUserInteractionEnabled = true
        return imageView
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
        if let banner = currentBanner {
            onTap?(banner)
        }
    }

    override func configureHierarchy() {
        contentView.addSubview(bannerImageView)
    }

    override func configureLayout() {
        bannerImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func configure(with banner: Banner) {
        currentBanner = banner
        bannerImageView.setFeelterImage(with: banner.imageURL)
    }
}
