//
//  FeelterButton.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import UIKit
import Combine

final class FeelterButton: UIButton {

    // MARK: - Properties
    private let tapSubject = PassthroughSubject<Void, Never>()
    var tapPublisher: AnyPublisher<Void, Never> {
        tapSubject.eraseToAnyPublisher()
    }

    override var isEnabled: Bool {
        didSet {
            updateAppearance()
        }
    }

    // MARK: - Initialization
    init(title: String) {
        super.init(frame: .zero)
        setupButton(title: title)
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupButton(title: String) {
        setTitle(title, for: .normal)
        titleLabel?.font = TextStyle.Pretendard.body2
        layer.cornerRadius = Radius.s
        updateAppearance()
    }

    private func updateAppearance() {
        if isEnabled {
            backgroundColor = .Feelter.brightTurquoise
            setTitleColor(.Feelter.gray0, for: .normal)
        } else {
            backgroundColor = .Feelter.gray90
            setTitleColor(.Feelter.gray75, for: .normal)
        }
    }

    // MARK: - Actions
    @objc private func buttonTapped() {
        tapSubject.send()
    }
}
