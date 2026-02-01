//
//  FeelterTextField.swift
//  Feelter
//
//  Created by Suji Jang on 1/2/26.
//

import UIKit
import Combine

final class FeelterTextField: UITextField {

    // MARK: - Types
    enum BorderState {
        case normal
        case highlighted
        case error

        var color: UIColor? {
            switch self {
            case .normal:
                return .Feelter.gray75
            case .highlighted:
                return .Feelter.deepTurquoise
            case .error:
                return .Feelter.red
            }
        }
    }

    // MARK: - Properties
    private let textSubject = PassthroughSubject<String?, Never>()
    var textPublisher: AnyPublisher<String?, Never> {
        textSubject.eraseToAnyPublisher()
    }

    private let editingDidBeginSubject = PassthroughSubject<Void, Never>()
    var editingDidBeginPublisher: AnyPublisher<Void, Never> {
        editingDidBeginSubject.eraseToAnyPublisher()
    }

    private let editingDidEndSubject = PassthroughSubject<Void, Never>()
    var editingDidEndPublisher: AnyPublisher<Void, Never> {
        editingDidEndSubject.eraseToAnyPublisher()
    }

    private var currentBorderState: BorderState = .normal
    private let isSecure: Bool
    private let textContentTypeValue: UITextContentType?
    private let keyboardTypeValue: UIKeyboardType
    private let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
    var rightViewWidth: CGFloat? {
        didSet {
            setNeedsLayout()
        }
    }

    override var isSecureTextEntry: Bool {
        didSet {
            updateSecureIcon()
        }
    }

    private lazy var secureToggleButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        config.background.backgroundColor = .clear
        config.background.backgroundColorTransformer = nil
        config.baseForegroundColor = .Feelter.gray75

        let button = UIButton(configuration: config)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.addTarget(self, action: #selector(toggleSecureMode), for: .touchUpInside)
        return button
    }()

    // MARK: - Initialization
    init(
        placeholder: String,
        isSecure: Bool = false,
        textContentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .emailAddress
    ) {
        self.isSecure = isSecure
        self.textContentTypeValue = textContentType
        self.keyboardTypeValue = keyboardType
        super.init(frame: .zero)
        setupTextField(placeholder: placeholder)
        addActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupTextField(placeholder: String) {
        font = TextStyle.Pretendard.caption1
        textColor = .Feelter.gray0
        attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.Feelter.gray75 ?? .gray]
        )
        backgroundColor = .clear
        layer.borderWidth = 1
        layer.cornerRadius = Radius.s
        setBorderState(.normal)
        tintColor = .Feelter.deepTurquoise
        textContentType = textContentTypeValue
        keyboardType = keyboardTypeValue
        leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        leftViewMode = .always

        if isSecure {
            isSecureTextEntry = true
            rightView = secureToggleButton
            rightViewMode = .always
        } else {
            rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
            rightViewMode = .always
        }
    }

    private func addActions() {
        addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        addTarget(self, action: #selector(editingDidBegin), for: .editingDidBegin)
        addTarget(self, action: #selector(editingDidEnd), for: .editingDidEnd)
    }

    // MARK: - Public Methods
    func setBorderState(_ state: BorderState) {
        currentBorderState = state
        layer.borderColor = state.color?.cgColor
    }

    override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        guard let width = rightViewWidth, width > 0, rightView != nil else {
            return super.rightViewRect(forBounds: bounds)
        }
        return CGRect(
            x: bounds.width - width,
            y: 0,
            width: width,
            height: bounds.height
        )
    }

    private func updateSecureIcon() {
        guard isSecure else { return }

        UIView.performWithoutAnimation {
            var config = secureToggleButton.configuration
            config?.image = isSecureTextEntry
                ? UIImage(systemName: "eye.slash", withConfiguration: iconConfig)
                : UIImage(systemName: "eye", withConfiguration: iconConfig)
            secureToggleButton.configuration = config
        }
    }

    // MARK: - Actions
    @objc private func textDidChange() {
        textSubject.send(text)
    }

    @objc private func editingDidBegin() {
        setBorderState(.highlighted)
        editingDidBeginSubject.send()
    }

    @objc private func editingDidEnd() {
        // 에러 상태가 아닐 때만 normal로 변경
        if currentBorderState != .error {
            setBorderState(.normal)
        }
        editingDidEndSubject.send()
    }

    @objc private func toggleSecureMode() {
        isSecureTextEntry.toggle()
    }
}
