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

    private let bannerImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 22
        imageView.backgroundColor = .Feelter.gray100
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureHierarchy() {
        contentView.addSubview(bannerImageView)
    }

    override func configureLayout() {
        bannerImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func configure(with imageURL: String?) {
        guard let imageURL = imageURL, let url = URL(string: imageURL) else {
            bannerImageView.image = nil
            return
        }
        bannerImageView.kf.setImage(with: url)
    }
}
