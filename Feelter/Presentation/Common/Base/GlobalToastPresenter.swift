//
//  GlobalToastPresenter.swift
//  Feelter
//
//  Created by Codex on 2/23/26.
//

import UIKit

@MainActor
final class GlobalToastPresenter {

    static let shared = GlobalToastPresenter()

    private weak var currentToastView: UIView?
    private var hideWorkItem: DispatchWorkItem?

    private init() { }

    func show(message: String, duration: TimeInterval = 3.0) {
        guard let window = keyWindow() else { return }

        hideWorkItem?.cancel()
        currentToastView?.removeFromSuperview()

        let toastView = ToastContainerView(message: message)
        toastView.alpha = 0
        window.addSubview(toastView)

        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            toastView.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 20),
            toastView.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -20),
            toastView.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])

        window.layoutIfNeeded()
        UIView.animate(withDuration: 0.2) {
            toastView.alpha = 1
        }

        currentToastView = toastView

        let workItem = DispatchWorkItem { [weak self, weak toastView] in
            guard let self, let toastView else { return }
            UIView.animate(withDuration: 0.2, animations: {
                toastView.alpha = 0
            }, completion: { _ in
                toastView.removeFromSuperview()
                if self.currentToastView === toastView {
                    self.currentToastView = nil
                }
            })
        }

        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func keyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)
    }
}

private final class ToastContainerView: UIView {

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .Feelter.gray0
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    init(message: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = Radius.s
        layer.cornerCurve = .continuous
        backgroundColor = UIColor.Feelter.gray90?.withAlphaComponent(0.95)

        messageLabel.text = message

        addSubview(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
