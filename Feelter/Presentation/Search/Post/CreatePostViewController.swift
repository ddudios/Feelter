//
//  CreatePostViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import UIKit
import SnapKit
import Combine
import CoreLocation
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

final class CreatePostViewController: BaseViewController {

    // MARK: - Properties

    private let viewModel: CreatePostViewModel
    private var cancellables = Set<AnyCancellable>()

    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let saveButtonTappedSubject = PassthroughSubject<CreatePostViewModel.ValidatedPostInput, Never>()

    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocationCoordinate2D?
    private var hasReceivedLocation = false

    private var attachmentItems: [AttachmentItem] = []
    private weak var activeInputView: UIView?

    private lazy var backgroundTapGesture = UITapGestureRecognizer(
        target: self,
        action: #selector(backgroundTapped)
    )

    // MARK: - Layout Constants

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 16
        static let textFieldHeight: CGFloat = 44
        static let textViewHeight: CGFloat = 160
        static let sectionSpacing: CGFloat = 20
        static let labelSpacing: CGFloat = 8
        static let categorySpacing: CGFloat = 8
        static let scrollBottomInset: CGFloat = 110
        static let attachmentPreviewSize: CGFloat = 96
        static let attachmentButtonHeight: CGFloat = 32
        static let attachmentButtonSpacing: CGFloat = 8
        static let attachmentStackSpacing: CGFloat = 12
        static let attachmentScrollHeight: CGFloat = 140
        static let attachmentRemoveButtonSize: CGFloat = 24
        static let attachmentRemoveButtonInset: CGFloat = 4
        static let metadataCellHeight: CGFloat = 140
        static let maxAttachments: Int = 5
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

    private let titleTitleLabel = SectionTitleLabel(title: "제목")
    private let titleTextField = FeelterTextField(
        placeholder: "제목을 입력해주세요.",
        textContentType: .none,
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

    private let attachmentTitleLabel = SectionTitleLabel(title: "첨부")
    private let attachmentTitleSpacerView = UIView()
    private lazy var attachmentTitleStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [attachmentTitleLabel, attachmentTitleSpacerView, attachmentAddButton])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = Layout.labelSpacing
        return stackView
    }()
    private let attachmentAddButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("추가하기", for: .normal)
        button.setTitleColor(.Feelter.gray75, for: .normal)
        button.titleLabel?.font = TextStyle.Pretendard.caption1
        return button
    }()

    private let attachmentsScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        return scrollView
    }()
    private let attachmentsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = Layout.attachmentStackSpacing
        return stackView
    }()

    private let locationMetadataView = FilterMetadataContainerView()

    private let contentTitleLabel = SectionTitleLabel(title: "내용")
    private let contentTextView = UITextView()
    private let contentPlaceholderLabel = UILabel()

    private var categoryButtons: [SelectableCapsuleButton] = []
    private var baseScrollBottomInset: CGFloat = 0
    private var editContext: CreatePostViewModel.EditContext? {
        if case let .edit(context) = viewModel.mode {
            return context
        }
        return nil
    }

    // MARK: - Initializer

    init(viewModel: CreatePostViewModel = DIContainer.shared.resolve(CreatePostViewModel.self)) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = editContext == nil ? "POST" : "EDIT"
        configureLocation()
        setupKeyboardObservers()
        bindViewModel()
        viewDidLoadSubject.send(())
        applyEditContextIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if editContext != nil {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
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
            titleTitleLabel,
            titleTextField,
            categoryTitleLabel,
            categoryStackView,
            attachmentTitleStackView,
            attachmentsScrollView,
            contentTitleLabel,
            contentTextView,
            locationMetadataView
        ].forEach { contentStackView.addArrangedSubview($0) }

        attachmentsScrollView.addSubview(attachmentsStackView)
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

        titleTextField.snp.makeConstraints { make in
            make.height.equalTo(Layout.textFieldHeight)
        }

        contentTextView.snp.makeConstraints { make in
            make.height.equalTo(Layout.textViewHeight)
        }

        attachmentsScrollView.snp.makeConstraints { make in
            make.height.equalTo(Layout.attachmentScrollHeight)
        }

        attachmentsStackView.snp.makeConstraints { make in
            make.edges.equalTo(attachmentsScrollView.contentLayoutGuide)
            make.height.equalTo(attachmentsScrollView.frameLayoutGuide)
        }

        locationMetadataView.snp.makeConstraints { make in
            make.height.equalTo(Layout.metadataCellHeight)
        }
    }

    override func configureView() {
        super.configureView()
        additionalSafeAreaInsets.bottom = Layout.scrollBottomInset
        view.gestureRecognizers?
            .filter { $0 is UITapGestureRecognizer }
            .forEach { view.removeGestureRecognizer($0) }
        backgroundTapGesture.cancelsTouchesInView = false
        backgroundTapGesture.delegate = self
        scrollView.addGestureRecognizer(backgroundTapGesture)

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

        titleTextField.autocapitalizationType = .sentences
        titleTextField.delegate = self

        contentTextView.font = TextStyle.Pretendard.caption1
        contentTextView.textColor = .Feelter.gray0
        contentTextView.backgroundColor = .clear
        contentTextView.layer.borderWidth = 1
        contentTextView.layer.cornerRadius = Radius.s
        contentTextView.layer.borderColor = UIColor.Feelter.gray75?.cgColor
        contentTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        contentTextView.delegate = self

        contentPlaceholderLabel.text = "내용을 입력해주세요."
        contentPlaceholderLabel.font = TextStyle.Pretendard.caption1
        contentPlaceholderLabel.textColor = .Feelter.gray75
        contentPlaceholderLabel.isUserInteractionEnabled = false
        contentTextView.addSubview(contentPlaceholderLabel)
        contentPlaceholderLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(12)
        }

        setupCategoryButtons()
        setupStackSpacing()

        attachmentAddButton.addTarget(self, action: #selector(attachmentAddButtonTapped), for: .touchUpInside)
        attachmentTitleSpacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        attachmentTitleSpacerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        updateLocationMetadata(coordinate: nil)
        locationMetadataView.configureForLocation()

        updateAttachmentPreviews()
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
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: titleTitleLabel)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: titleTextField)
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: categoryTitleLabel)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: categoryStackView)
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: attachmentTitleStackView)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: attachmentsScrollView)
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: contentTitleLabel)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: contentTextView)
    }

    private func applyEditContextIfNeeded() {
        guard let context = editContext else { return }
        titleTextField.text = context.title
        contentTextView.text = context.content
        contentPlaceholderLabel.isHidden = !context.content.isEmpty
        updateCategorySelection(selectedCategory: context.category)
        attachmentItems = context.filePaths.map { makeExistingAttachmentItem(from: $0) }
        updateAttachmentPreviews()
    }

    private func updateCategorySelection(selectedCategory: String) {
        let trimmedCategory = selectedCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selectedButton = categoryButtons.first(where: { $0.titleLabel?.text == trimmedCategory }) {
            categoryButtons.forEach { $0.isSelected = ($0 == selectedButton) }
        }
    }

    private func makeExistingAttachmentItem(from path: String) -> AttachmentItem {
        let isVideo = isVideoFilePath(path)
        return AttachmentItem(
            data: nil,
            fileExtension: nil,
            previewImage: nil,
            remotePath: path,
            isVideo: isVideo
        )
    }

    private func isVideoFilePath(_ path: String) -> Bool {
        let fileExtension = (path as NSString).pathExtension.lowercased()
        return ["mp4", "mov", "m4v"].contains(fileExtension)
    }

    private func configureLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
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

    // MARK: - ViewModel Binding

    private func bindViewModel() {
        let input = CreatePostViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            saveButtonTapped: saveButtonTappedSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.saveResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                let isEditing = self?.editContext != nil
                switch result {
                case .success:
                    let message = isEditing == true ? "게시글이 수정되었습니다." : "게시글이 등록되었습니다."
                    self?.showAlert(message: message) { [weak self] in
                        if isEditing == false {
                            self?.clearPostForm()
                        }
                        self?.navigateToSearchAndRefresh()
                    }
                case .failure(let error):
                    let message = isEditing == true
                    ? "게시글 수정에 실패했습니다.\n\(error.localizedDescription)"
                    : "게시글 등록에 실패했습니다.\n\(error.localizedDescription)"
                    self?.showAlert(message: message)
                }
            }
            .store(in: &cancellables)

        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.navigationItem.rightBarButtonItem?.isEnabled = !isLoading
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func categoryButtonTapped(_ sender: SelectableCapsuleButton) {
        categoryButtons.forEach { $0.isSelected = ($0 == sender) }
    }

    @objc private func saveButtonTapped() {
        let fieldsResult = validateFields()

        switch fieldsResult {
        case .success(let fields):
            if let coordinate = currentLocation {
                submitPost(fields: fields, coordinate: coordinate)
            } else {
                showLocationFallbackAlert(fields: fields)
            }
        case .failure(let error):
            showAlert(message: error.message)
        }
    }

    @objc private func attachmentAddButtonTapped() {
        guard attachmentItems.count < Layout.maxAttachments else {
            showAlert(message: "첨부는 최대 \(Layout.maxAttachments)개까지 가능합니다.")
            return
        }

        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = Layout.maxAttachments - attachmentItems.count
        configuration.filter = .any(of: [.images, .videos])

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func applyFilterButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < attachmentItems.count else { return }
        let viewController = ApplyFilterViewController()
        navigationController?.pushViewController(viewController, animated: true)
    }

    @objc private func removeAttachmentButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < attachmentItems.count else { return }
        attachmentItems.remove(at: index)
        updateAttachmentPreviews()
    }

    @objc private func backgroundTapped() {
        dismissKeyboard()
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardFrame = view.convert(frame, from: nil)
        let overlap = max(0, scrollView.frame.maxY - keyboardFrame.minY)
        let bottomInset = baseScrollBottomInset + overlap
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset

        if let activeInputView {
            scrollToVisible(activeInputView)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = baseScrollBottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = baseScrollBottomInset
    }

    // MARK: - Helpers

    private func scrollToVisible(_ view: UIView, animated: Bool = true) {
        let rect = view.convert(view.bounds, to: scrollView)
        let targetRect = rect.insetBy(dx: 0, dy: -Layout.labelSpacing)
        scrollView.scrollRectToVisible(targetRect, animated: animated)
    }

    private func updateAttachmentPreviews() {
        attachmentsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if attachmentItems.isEmpty {
            attachmentsScrollView.isHidden = true
        } else {
            attachmentsScrollView.isHidden = false
            for (index, item) in attachmentItems.enumerated() {
                let view = makeAttachmentRowView(item: item, index: index)
                attachmentsStackView.addArrangedSubview(view)
            }
        }

        attachmentAddButton.isEnabled = attachmentItems.count < Layout.maxAttachments
        attachmentAddButton.alpha = attachmentAddButton.isEnabled ? 1 : 0.4

        view.layoutIfNeeded()
    }

    @MainActor
    private func updateLocationMetadata(coordinate: CLLocationCoordinate2D?) {
        let metadata = makeLocationMetadata(coordinate: coordinate)
        locationMetadataView.configure(metadata: metadata)
    }

    private func makeLocationMetadata(coordinate: CLLocationCoordinate2D?) -> PhotoMetadata {
        return PhotoMetadata(
            camera: "위치 정보",
            lensInfo: "",
            focalLength: 0,
            aperture: 0,
            iso: 0,
            shutterSpeed: "-",
            pixelWidth: 0,
            pixelHeight: 0,
            fileSizeBytes: 0,
            resolution: "-",
            fileSize: "-",
            takenDate: nil,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude
        )
    }

    private func makeAttachmentRowView(item: AttachmentItem, index: Int) -> UIView {
        let containerStackView = UIStackView()
        containerStackView.axis = .vertical
        containerStackView.alignment = .center
        containerStackView.spacing = Layout.attachmentButtonSpacing

        let previewContainerView = UIView()
        previewContainerView.backgroundColor = .Feelter.gray90
        previewContainerView.layer.cornerRadius = Radius.m
        previewContainerView.clipsToBounds = true
        containerStackView.addArrangedSubview(previewContainerView)

        previewContainerView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.attachmentPreviewSize)
        }

        let previewImageView = UIImageView()
        if let previewImage = item.previewImage {
            previewImageView.image = previewImage
            previewImageView.contentMode = .scaleAspectFill
        } else if let remotePath = item.remotePath, !item.isVideo {
            previewImageView.setFeelterImage(with: remotePath)
            previewImageView.contentMode = .scaleAspectFill
        } else {
            let fallbackName = item.isVideo ? "video.fill" : "photo"
            previewImageView.image = UIImage(systemName: fallbackName)
            previewImageView.contentMode = .scaleAspectFit
            previewImageView.tintColor = .Feelter.gray60
        }
        previewImageView.clipsToBounds = true
        previewContainerView.addSubview(previewImageView)

        previewImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        if item.isVideo {
            let playImageView = UIImageView(image: UIImage(systemName: "play.circle.fill"))
            playImageView.tintColor = .white
            playImageView.contentMode = .scaleAspectFit
            previewContainerView.addSubview(playImageView)
            playImageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(32)
            }
        }

        let removeButton = makeRemoveAttachmentButton()
        removeButton.tag = index
        removeButton.addTarget(self, action: #selector(removeAttachmentButtonTapped(_:)), for: .touchUpInside)
        previewContainerView.addSubview(removeButton)
        removeButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(Layout.attachmentRemoveButtonInset)
            make.width.height.equalTo(Layout.attachmentRemoveButtonSize)
        }

        let applyButton = makeApplyFilterButton()
        applyButton.tag = index
        applyButton.addTarget(self, action: #selector(applyFilterButtonTapped), for: .touchUpInside)

        applyButton.snp.makeConstraints { make in
            make.height.equalTo(Layout.attachmentButtonHeight)
            make.width.equalTo(Layout.attachmentPreviewSize)
        }

        containerStackView.addArrangedSubview(applyButton)

        return containerStackView
    }

    private func makeApplyFilterButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("필터 적용", for: .normal)
        button.setTitleColor(.Feelter.gray45, for: .normal)
        button.setImage(UIImage.TabBar.filterFill, for: .normal)
        button.titleLabel?.font = TextStyle.Pretendard.caption1
        button.imageView?.contentMode = .scaleAspectFit
        button.semanticContentAttribute = .forceLeftToRight
        button.tintColor = .Feelter.gray45
        button.backgroundColor = .Feelter.brightTurquoise
        button.layer.cornerRadius = Radius.s
        button.layer.borderWidth = 0
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 10)
        return button
    }

    private func makeRemoveAttachmentButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = Layout.attachmentRemoveButtonSize / 2
        button.clipsToBounds = true
        return button
    }

    private func validateFields() -> Result<ValidatedPostFields, PostValidationError> {
        guard let category = categoryButtons.first(where: { $0.isSelected })?.titleLabel?.text else {
            return .failure(.emptyCategory)
        }

        guard let title = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return .failure(.emptyTitle)
        }

        let content = contentTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            return .failure(.emptyContent)
        }

        return .success(ValidatedPostFields(
            category: category,
            title: title,
            content: content
        ))
    }

    private func submitPost(fields: ValidatedPostFields, coordinate: CLLocationCoordinate2D) {
        let newFiles = attachmentItems.compactMap { $0.uploadFile }
        let existingFilePaths = attachmentItems.compactMap { $0.remotePath }

        let input = CreatePostViewModel.ValidatedPostInput(
            category: fields.category,
            title: fields.title,
            content: fields.content,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            newFiles: newFiles,
            existingFilePaths: existingFilePaths
        )

        saveButtonTappedSubject.send(input)
    }

    private func clearPostForm() {
        titleTextField.text = nil
        contentTextView.text = ""
        contentPlaceholderLabel.isHidden = false
        attachmentItems.removeAll()
        updateAttachmentPreviews()
        resetCategorySelection()
        view.endEditing(true)
    }

    private func resetCategorySelection() {
        guard let defaultButton = categoryButtons.first else { return }
        categoryButtons.forEach { $0.isSelected = ($0 == defaultButton) }
    }

    private func navigateToSearchAndRefresh() {
        guard let navigationController else { return }
        if let searchViewController = navigationController.viewControllers.first(where: { $0 is SearchViewController }) as? SearchViewController {
            searchViewController.refreshPosts()
            navigationController.popToViewController(searchViewController, animated: true)
        } else {
            navigationController.popToRootViewController(animated: true)
        }
    }

    private func showLocationFallbackAlert(fields: ValidatedPostFields) {
        let alert = UIAlertController(
            title: "위치 정보 필요",
            message: "현재 위치를 가져올 수 없습니다. 기본 위치로 등록할까요?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "기본 위치로 등록", style: .default) { [weak self] _ in
            guard let self else { return }
            let defaultCoordinate = CLLocationCoordinate2D(
                latitude: 37.654215,
                longitude: 127.049914
            )
            self.submitPost(fields: fields, coordinate: defaultCoordinate)
        })

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }

    private func showAlert(message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

// MARK: - Validation
private enum PostValidationError: Error {
    case emptyCategory
    case emptyTitle
    case emptyContent

    var message: String {
        switch self {
        case .emptyCategory:
            return "카테고리를 선택해주세요."
        case .emptyTitle:
            return "제목을 입력해주세요."
        case .emptyContent:
            return "내용을 입력해주세요."
        }
    }
}

private struct ValidatedPostFields {
    let category: String
    let title: String
    let content: String
}

private struct AttachmentItem {
    let data: Data?
    let fileExtension: String?
    let previewImage: UIImage?
    let remotePath: String?
    let isVideo: Bool

    var uploadFile: UploadFile? {
        guard let data, let fileExtension else { return nil }
        return UploadFile(data: data, fileExtension: fileExtension)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension CreatePostViewController {
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: scrollView)
        if isTouchInsideTextInputs(at: location) {
            return false
        }
        let touchedView = scrollView.hitTest(location, with: nil)
        return !isTouchInsideControl(from: touchedView)
    }

    private func isTouchInsideControl(from view: UIView?) -> Bool {
        guard let view else { return false }
        var currentView: UIView? = view
        while let candidate = currentView {
            if candidate is UIControl {
                return true
            }
            currentView = candidate.superview
        }
        return false
    }

    private func isTouchInsideTextInputs(at location: CGPoint) -> Bool {
        let inputs: [UIView] = [titleTextField, contentTextView]
        return inputs.contains { input in
            let inputFrame = input.convert(input.bounds, to: scrollView)
            return inputFrame.contains(location)
        }
    }
}

// MARK: - UITextFieldDelegate
extension CreatePostViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeInputView = textField
        scrollToVisible(textField)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if activeInputView === textField {
            activeInputView = nil
        }
    }
}

// MARK: - UITextViewDelegate
extension CreatePostViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        activeInputView = textView
        scrollToVisible(textView)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if activeInputView === textView {
            activeInputView = nil
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        contentPlaceholderLabel.isHidden = !textView.text.isEmpty
    }
}

// MARK: - CLLocationManagerDelegate
extension CreatePostViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            Task { @MainActor in
                self.updateLocationMetadata(coordinate: nil)
            }
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !hasReceivedLocation else { return }
        guard let coordinate = locations.last?.coordinate else { return }
        hasReceivedLocation = true
        currentLocation = coordinate
        Task { @MainActor in
            self.updateLocationMetadata(coordinate: coordinate)
        }
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
        Task { @MainActor in
            self.updateLocationMetadata(coordinate: nil)
        }
    }
}

// MARK: - PHPickerViewControllerDelegate
extension CreatePostViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }

        let dispatchGroup = DispatchGroup()
        var loadedItems: [AttachmentItem?] = Array(repeating: nil, count: results.count)

        for (index, result) in results.enumerated() {
            let provider = result.itemProvider

            if isVideoProvider(provider) {
                dispatchGroup.enter()
                loadVideoAttachment(from: provider) { item in
                    loadedItems[index] = item
                    dispatchGroup.leave()
                }
                continue
            }

            guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
            dispatchGroup.enter()
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                defer { dispatchGroup.leave() }
                guard let image = object as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.8) else { return }
                loadedItems[index] = AttachmentItem(
                    data: data,
                    fileExtension: "jpg",
                    previewImage: image,
                    remotePath: nil,
                    isVideo: false
                )
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let newItems = loadedItems.compactMap { $0 }
            guard !newItems.isEmpty else { return }
            self.attachmentItems.append(contentsOf: newItems)
            self.updateAttachmentPreviews()
        }
    }

    private func isVideoProvider(_ provider: NSItemProvider) -> Bool {
        return provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
        || provider.hasItemConformingToTypeIdentifier(UTType.video.identifier)
    }

    private func loadVideoAttachment(
        from provider: NSItemProvider,
        completion: @escaping (AttachmentItem?) -> Void
    ) {
        let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
        ? UTType.movie.identifier
        : UTType.video.identifier

        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] fileURL, _ in
            guard let self, let fileURL else {
                completion(nil)
                return
            }

            let fileExtension = fileURL.pathExtension.isEmpty ? "mov" : fileURL.pathExtension.lowercased()
            guard let data = try? Data(contentsOf: fileURL) else {
                completion(nil)
                return
            }

            let previewImage = self.makeVideoThumbnail(from: fileURL)
            let item = AttachmentItem(
                data: data,
                fileExtension: fileExtension,
                previewImage: previewImage,
                remotePath: nil,
                isVideo: true
            )
            completion(item)
        }
    }

    private func makeVideoThumbnail(from fileURL: URL) -> UIImage? {
        let asset = AVAsset(url: fileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        if let imageRef = try? generator.copyCGImage(at: time, actualTime: nil) {
            return UIImage(cgImage: imageRef)
        }
        return nil
    }
}
