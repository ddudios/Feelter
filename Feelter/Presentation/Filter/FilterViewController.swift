//
//  FilterViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit
import SnapKit
import PhotosUI

final class FilterViewController: BaseViewController {

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 16
        static let textFieldHeight: CGFloat = 44
        static let photoButtonHeight: CGFloat = 96
        static let sectionSpacing: CGFloat = 20
        static let labelSpacing: CGFloat = 8
        static let categorySpacing: CGFloat = 8
        static let currencyViewWidth: CGFloat = 44
        static let scrollBottomInset: CGFloat = 110
    }

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    private let contentView = UIView()
    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = Layout.sectionSpacing
        return stackView
    }()

    private let filterNameTitleLabel = SectionTitleLabel(title: "필터명")
    private let filterNameTextField = FeelterTextField(
        placeholder: "필터 이름을 입력해주세요.",
        textContentType: .name,
        keyboardType: .default
    )

    private let categoryTitleLabel = SectionTitleLabel(title: "카테고리")
    private let categoryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = Layout.categorySpacing
        stackView.distribution = .fillProportionally
        return stackView
    }()

    private let photoTitleLabel = SectionTitleLabel(title: "대표 사진 등록")
    private let photoUploadButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.Icon.add, for: .normal)
        button.tintColor = .Feelter.gray60
        button.backgroundColor = .Feelter.blackTurquoise
        button.layer.cornerRadius = Radius.m
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.Feelter.deepTurquoise?.cgColor
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()

    private let descriptionTitleLabel = SectionTitleLabel(title: "필터 소개")
    private let descriptionTextField = FeelterTextField(
        placeholder: "이 필터에 대해 간단하게 소개해주세요.",
        textContentType: nil,
        keyboardType: .default
    )

    private let priceTitleLabel = SectionTitleLabel(title: "판매 가격")
    private let priceTextField = FeelterTextField(
        placeholder: "1,000",
        textContentType: nil,
        keyboardType: .numberPad
    )

    private var categoryButtons: [SelectableCapsuleButton] = []
    private weak var activeTextField: UITextField?
    private var selectedPhotoImage: UIImage?
    private var baseScrollBottomInset: CGFloat = 0

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MAKE"
        setupKeyboardObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStackView)

        [
            filterNameTitleLabel,
            filterNameTextField,
            categoryTitleLabel,
            categoryStackView,
            photoTitleLabel,
            photoUploadButton,
            descriptionTitleLabel,
            descriptionTextField,
            priceTitleLabel,
            priceTextField
        ].forEach { contentStackView.addArrangedSubview($0) }
    }

    override func configureLayout() {
        super.configureLayout()
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(
                UIEdgeInsets(
                    top: Layout.verticalInset,
                    left: Layout.horizontalInset,
                    bottom: Layout.verticalInset,
                    right: Layout.horizontalInset
                )
            )
        }

        filterNameTextField.snp.makeConstraints { make in
            make.height.equalTo(Layout.textFieldHeight)
        }

        descriptionTextField.snp.makeConstraints { make in
            make.height.equalTo(Layout.textFieldHeight)
        }

        priceTextField.snp.makeConstraints { make in
            make.height.equalTo(Layout.textFieldHeight)
        }

        photoUploadButton.snp.makeConstraints { make in
            make.height.equalTo(Layout.photoButtonHeight)
        }
    }

    override func configureView() {
        super.configureView()
        additionalSafeAreaInsets.bottom = Layout.scrollBottomInset
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage.Icon.save,
            style: .plain,
            target: self,
            action: #selector(saveButtonTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .Feelter.gray75

        scrollView.delaysContentTouches = false
        baseScrollBottomInset = 0
        scrollView.contentInset.bottom = baseScrollBottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = baseScrollBottomInset

        filterNameTextField.autocapitalizationType = .words
        descriptionTextField.autocapitalizationType = .sentences
        priceTextField.keyboardType = .numberPad
        priceTextField.rightView = makeCurrencyRightView()
        priceTextField.rightViewMode = .always
        [filterNameTextField, descriptionTextField, priceTextField].forEach { $0.delegate = self }

        setupCategoryButtons()
        setupStackSpacing()

        photoUploadButton.addTarget(self, action: #selector(photoUploadButtonTapped), for: .touchUpInside)
    }

    private func setupCategoryButtons() {
        let categories = ["푸드", "인물", "풍경", "야경", "별"]
        let defaultCategory = "푸드"

        categories.forEach { title in
            let button = SelectableCapsuleButton(title: title, isSelected: title == defaultCategory)
            button.addTarget(self, action: #selector(categoryButtonTapped(_:)), for: .touchUpInside)
            categoryButtons.append(button)
            categoryStackView.addArrangedSubview(button)
        }
    }

    private func setupStackSpacing() {
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: filterNameTitleLabel)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: filterNameTextField)
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: categoryTitleLabel)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: categoryStackView)
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: photoTitleLabel)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: photoUploadButton)
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: descriptionTitleLabel)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: descriptionTextField)
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: priceTitleLabel)
    }

    private func makeCurrencyRightView() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: Layout.currencyViewWidth, height: Layout.textFieldHeight))
        let label = UILabel()
        label.text = "원"
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .Feelter.gray60
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }
        return container
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func scrollToVisible(_ view: UIView, animated: Bool = true) {
        let rect = view.convert(view.bounds, to: scrollView)
        let targetRect = rect.insetBy(dx: 0, dy: -Layout.labelSpacing)
        scrollView.scrollRectToVisible(targetRect, animated: animated)
    }

    @objc private func categoryButtonTapped(_ sender: SelectableCapsuleButton) {
        categoryButtons.forEach { $0.isSelected = ($0 == sender) }
    }

    @objc private func saveButtonTapped() { }

    @objc private func photoUploadButtonTapped() {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardFrame = view.convert(frame, from: nil)
        let overlap = max(0, scrollView.frame.maxY - keyboardFrame.minY)
        let bottomInset = baseScrollBottomInset + overlap
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset

        if let activeTextField {
            scrollToVisible(activeTextField)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = baseScrollBottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = baseScrollBottomInset
    }

    private func updatePhotoUploadButton(with image: UIImage) {
        selectedPhotoImage = image
        photoUploadButton.setBackgroundImage(nil, for: .normal)
        photoUploadButton.setImage(image, for: .normal)
        photoUploadButton.imageView?.contentMode = .scaleAspectFill
        photoUploadButton.contentHorizontalAlignment = .fill
        photoUploadButton.contentVerticalAlignment = .fill
        photoUploadButton.clipsToBounds = true
    }
}

// MARK: - UITextFieldDelegate
extension FilterViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeTextField = textField
        scrollToVisible(textField)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if activeTextField === textField {
            activeTextField = nil
        }
    }
}

// MARK: - PHPickerViewControllerDelegate
extension FilterViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self.updatePhotoUploadButton(with: image)
            }
        }
    }
}
