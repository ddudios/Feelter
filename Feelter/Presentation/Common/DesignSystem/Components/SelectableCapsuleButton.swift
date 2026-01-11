//
//  SelectableCapsuleButton.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import UIKit

final class SelectableCapsuleButton: UIButton {
    private enum Layout {
        static let height: CGFloat = 28
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 6
    }

    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }

    init(title: String, isSelected: Bool = false) {
        super.init(frame: .zero)
        configureButton(title: title)
        self.isSelected = isSelected
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureButton(title: String) {
        setTitle(title, for: .normal)
        layer.cornerRadius = Layout.height / 2
        layer.cornerCurve = .continuous
        contentEdgeInsets = UIEdgeInsets(
            top: Layout.verticalPadding,
            left: Layout.horizontalPadding,
            bottom: Layout.verticalPadding,
            right: Layout.horizontalPadding
        )
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        heightAnchor.constraint(equalToConstant: Layout.height).isActive = true
    }

    private func updateAppearance() {
        if isSelected {
            backgroundColor = .Feelter.brightTurquoise
            titleLabel?.font = TextStyle.Pretendard.title2
            setTitleColor(.Feelter.gray0, for: .normal)
        } else {
            backgroundColor = .Feelter.blackTurquoise
            titleLabel?.font = TextStyle.Pretendard.body2
            setTitleColor(.Feelter.gray75, for: .normal)
        }
    }
}
