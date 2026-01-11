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
    }

    private var imageViews: [UIImageView] = []
    private var heightConstraint: Constraint?
    private var rootStackView: UIStackView?

    func configure(with images: [ChatImageSource]) {
        imageViews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()

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

        updateLayout(for: imageViews.count)
    }

    private func updateLayout(for count: Int) {
        heightConstraint?.deactivate()
        rootStackView?.removeFromSuperview()

        guard count > 0 else { return }

        if count == 2 {
            snp.makeConstraints { make in
                heightConstraint = make.height.equalTo(snp.width).multipliedBy(0.5).constraint
            }
        } else {
            snp.makeConstraints { make in
                heightConstraint = make.height.equalTo(snp.width).constraint
            }
        }

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
