//
//  ChatImageGridView.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import UIKit
import SnapKit

final class ChatImageGridView: UIView {

    private enum Layout {
        static let spacing: CGFloat = 2
        /// 최대 너비 = 최대 높이 (1:1 비율 제한, 화면 너비의 약 60%)
        static let maxSize: CGFloat = min(UIScreen.main.bounds.width * 0.6, 250)
    }

    private var imageViews: [UIImageView] = []
    private var heightConstraint: Constraint?
    private var maxHeightConstraint: Constraint?
    private var rootStackView: UIStackView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupInitialConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInitialConstraints()
    }

    private func setupInitialConstraints() {
        // 초기에는 높이 0으로 설정 (이미지 없는 상태)
        snp.makeConstraints { make in
            heightConstraint = make.height.equalTo(0).priority(.high).constraint
        }
    }

    func configure(with images: [ChatImageSource]) {
        // 기존 이미지뷰 제거
        imageViews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        rootStackView?.removeFromSuperview()
        rootStackView = nil

        // 기존 제약 비활성화
        heightConstraint?.deactivate()
        heightConstraint = nil
        maxHeightConstraint?.deactivate()
        maxHeightConstraint = nil

        // 이미지가 없으면 높이 0으로 설정
        if images.isEmpty {
            snp.makeConstraints { make in
                heightConstraint = make.height.equalTo(0).priority(.high).constraint
            }
            return
        }

        let limitedImages = Array(images.prefix(5))
        limitedImages.forEach { source in
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = .Feelter.gray90
            switch source {
            case .local(let image):
                imageView.image = image
            case .remote(let path):
                imageView.setFeelterImage(with: path)
            }
            imageViews.append(imageView)
        }

        // 이미지 개수에 따른 높이 설정
        // - 2개: 가로 배치이므로 높이를 절반으로
        // - 나머지: 정사각형 (최대 높이 = 최대 너비)
        let imageCount = imageViews.count
        let targetHeight: CGFloat = imageCount == 2 ? Layout.maxSize / 2 : Layout.maxSize

        snp.makeConstraints { make in
            // 기본 높이 설정
            heightConstraint = make.height.equalTo(targetHeight).priority(.high).constraint
            // 최대 높이 제한 (높이 <= 최대 너비, 1:1 비율 제한)
            maxHeightConstraint = make.height.lessThanOrEqualTo(Layout.maxSize).constraint
        }

        layoutImages(for: imageViews.count)
    }

    private func layoutImages(for count: Int) {
        switch count {
        case 1:
            layoutSingleImage()
        case 2:
            let rowStack = makeHorizontalStack(views: [imageViews[0], imageViews[1]])
            attach(stackView: rowStack)
        case 3:
            let rightColumn = makeVerticalStack(views: [imageViews[1], imageViews[2]])
            let rowStack = makeHorizontalStack(views: [imageViews[0], rightColumn])
            attach(stackView: rowStack)
        case 4:
            let topRow = makeHorizontalStack(views: [imageViews[0], imageViews[1]])
            let bottomRow = makeHorizontalStack(views: [imageViews[2], imageViews[3]])
            let columnStack = makeVerticalStack(views: [topRow, bottomRow])
            attach(stackView: columnStack)
        case 5:
            let topRow = makeHorizontalStack(views: [imageViews[0], imageViews[1], imageViews[2]])
            let bottomRow = makeHorizontalStack(views: [imageViews[3], imageViews[4]])
            let columnStack = makeVerticalStack(views: [topRow, bottomRow])
            attach(stackView: columnStack)
        default:
            layoutSingleImage()
        }
    }

    private func layoutSingleImage() {
        guard let imageView = imageViews.first else { return }
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func attach(stackView: UIStackView) {
        rootStackView = stackView
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func makeHorizontalStack(views: [UIView]) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: views)
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = Layout.spacing
        return stackView
    }

    private func makeVerticalStack(views: [UIView]) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: views)
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = Layout.spacing
        return stackView
    }
}
