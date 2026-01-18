//
//  FilterViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit
import SnapKit
import PhotosUI
import Photos
import ImageIO
import UniformTypeIdentifiers
import Combine
import Kingfisher

final class FilterMakeViewController: BaseViewController {

    // MARK: - Properties

    private let mode: FilterEditorMode
    private let viewModel: FilterMakeViewModel
    private var cancellables = Set<AnyCancellable>()

    /// 수정 완료 후 업데이트된 데이터를 전달하는 클로저
    var onUpdateComplete: ((FilterDetail) -> Void)?

    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let saveButtonTappedSubject = PassthroughSubject<FilterMakeViewModel.ValidatedFilterInput, Never>()

    // MARK: - Layout Constants

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 16
        static let textFieldHeight: CGFloat = 44
        static let photoButtonHeight: CGFloat = 96
        static let metadataCellHeight: CGFloat = 140
        static let sectionSpacing: CGFloat = 20
        static let labelSpacing: CGFloat = 8
        static let categorySpacing: CGFloat = 8
        static let currencyViewWidth: CGFloat = 36
        static let scrollBottomInset: CGFloat = 110
        static let currencyTrailingInset: CGFloat = 8
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
    private let photoTitleSpacerView = UIView()
    private lazy var photoTitleStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [photoTitleLabel, photoTitleSpacerView, photoEditButton])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = Layout.labelSpacing
        return stackView
    }()
    private let photoEditButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("수정하기", for: .normal)
        button.setTitleColor(.Feelter.gray75, for: .normal)
        button.titleLabel?.font = TextStyle.Pretendard.caption1
        button.isHidden = true
        return button
    }()
    private let photoUploadButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.Icon.add, for: .normal)
        button.tintColor = .Feelter.gray60
        button.backgroundColor = .Feelter.blackTurquoise
        button.layer.cornerRadius = Radius.m
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.Feelter.deepTurquoise?.cgColor
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    private let metadataCell = FilterMetadataCell()

    private let descriptionTitleLabel = SectionTitleLabel(title: "필터 소개")
    private let descriptionTextField = FeelterTextField(
        placeholder: "이 필터에 대해 간단하게 소개해주세요.",
        textContentType: nil,
        keyboardType: .default
    )

    private let priceTitleLabel = SectionTitleLabel(title: "판매 가격")
    private let priceTextField = FeelterTextField(
        placeholder: "100",
        textContentType: nil,
        keyboardType: .numberPad
    )

    private var categoryButtons: [SelectableCapsuleButton] = []
    private weak var activeTextField: UITextField?
    private var selectedPhotoImage: UIImage?
    private var currentPhotoMetadata: PhotoMetadata?

    // 원본 이미지 보관 (여러 번 편집을 위해)
    private var originalPhotoImage: UIImage?
    // 필터 적용된 이미지 (서버 업로드용)
    private var filteredPhotoImage: UIImage?
    // 현재 필터 값 (서버 전송용)
    private var currentFilterValues: FilterValues?

    private var photoUploadButtonHeightConstraint: Constraint?
    private var photoUploadButtonSquareConstraint: NSLayoutConstraint?
    private var baseScrollBottomInset: CGFloat = 0
    private lazy var backgroundTapGesture = UITapGestureRecognizer(
        target: self,
        action: #selector(backgroundTapped)
    )

    // MARK: - Initializer

    init(
        mode: FilterEditorMode = .create,
        viewModel: FilterMakeViewModel? = nil
    ) {
        self.mode = mode
        self.viewModel = viewModel ?? FilterMakeViewModel(mode: mode)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = mode.navigationTitle
        setupKeyboardObservers()
        bindViewModel()
        viewDidLoadSubject.send(())
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
            photoTitleStackView,
            photoUploadButton,
            metadataCell,
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
            photoUploadButtonHeightConstraint = make.height.equalTo(Layout.photoButtonHeight).constraint
        }

        photoUploadButtonSquareConstraint = photoUploadButton.heightAnchor.constraint(equalTo: photoUploadButton.widthAnchor)
        photoUploadButtonSquareConstraint?.isActive = false

        metadataCell.snp.makeConstraints { make in
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

        filterNameTextField.autocapitalizationType = .words
        descriptionTextField.autocapitalizationType = .sentences
        priceTextField.keyboardType = .numberPad
        priceTextField.rightView = makeCurrencyRightView()
        priceTextField.rightViewMode = .always
        priceTextField.rightViewWidth = Layout.currencyViewWidth
        priceTextField.isEnabled = true
        priceTextField.isUserInteractionEnabled = true
        priceTextField.textColor = .Feelter.gray0 ?? .white
        priceTextField.tintColor = .Feelter.deepTurquoise ?? .systemTeal
        priceTextField.textAlignment = .left
        priceTextField.addTarget(self, action: #selector(priceTextFieldDidChange), for: .editingChanged)
        [filterNameTextField, descriptionTextField, priceTextField].forEach { $0.delegate = self }

        setupCategoryButtons()
        setupStackSpacing()

        photoUploadButton.addTarget(self, action: #selector(photoUploadButtonTapped), for: .touchUpInside)
        photoEditButton.addTarget(self, action: #selector(photoEditButtonTapped), for: .touchUpInside)
        metadataCell.isHidden = true
        metadataCell.configure(metadata: .empty)
        photoTitleSpacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        photoTitleSpacerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // 수정 모드 UI 제한 적용
        configureEditModeRestrictions()
    }

    /// 수정 모드일 때 이미지/필터값 변경 불가 처리
    private func configureEditModeRestrictions() {
        guard mode.isEditMode else { return }

        // 1. 이미지 업로드 버튼 인터랙션 차단
        photoUploadButton.isUserInteractionEnabled = false

        // 2. 필터 편집(수정하기) 버튼 숨김
        photoEditButton.isHidden = true

        // 3. 이미지 영역 시각적 표시 (고정 상태임을 알림)
        photoUploadButton.alpha = 0.8
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
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: photoTitleStackView)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: photoUploadButton)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: metadataCell)
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: descriptionTitleLabel)
        contentStackView.setCustomSpacing(Layout.sectionSpacing, after: descriptionTextField)
        contentStackView.setCustomSpacing(Layout.labelSpacing, after: priceTitleLabel)
    }

    private func makeCurrencyRightView() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: Layout.currencyViewWidth, height: Layout.textFieldHeight))
        container.isUserInteractionEnabled = false
        let label = UILabel()
        label.text = "원"
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .Feelter.gray60
        label.isUserInteractionEnabled = false
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Layout.currencyTrailingInset)
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

    // MARK: - ViewModel Binding

    private func bindViewModel() {
        let input = FilterMakeViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            saveButtonTapped: saveButtonTappedSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        // 수정 모드일 때 기존 데이터로 폼 채우기
        output.prefilledData
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.prefillForm(with: data)
            }
            .store(in: &cancellables)

        // 저장 결과 처리
        output.saveResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                switch result {
                case .success(let filterDetail):
                    self?.handleSaveSuccess(filterDetail: filterDetail)
                case .failure(let error):
                    self?.showAlert(message: "저장에 실패했습니다.\n\(error.localizedDescription)")
                }
            }
            .store(in: &cancellables)

        // 로딩 상태 처리
        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.navigationItem.rightBarButtonItem?.isEnabled = !isLoading
            }
            .store(in: &cancellables)
    }

    private func prefillForm(with data: FilterMakeViewModel.PrefilledFormData) {
        filterNameTextField.text = data.title
        descriptionTextField.text = data.description
        priceTextField.text = formatPriceText(from: String(data.price))

        // 카테고리 선택
        categoryButtons.forEach { button in
            button.isSelected = (button.titleLabel?.text == data.category)
        }

        // 기존 이미지 로드
        if let imageURLString = data.previewImageURL,
           let imageURL = URL(string: imageURLString) {
            loadExistingImage(from: imageURL)
        }

        // 메타데이터 설정
        if let metadata = data.metadata {
            currentPhotoMetadata = metadata
            metadataCell.configure(metadata: metadata)
            metadataCell.isHidden = false
        }
    }

    private func loadExistingImage(from url: URL) {
        // 상대 경로를 완전한 URL로 변환 (UIImageView+Extension과 동일한 방식)
        let path = url.scheme == nil ? url.path : url.absoluteString
        let fullPath = "\(Config.baseURL)/v1\(path)"

        guard let fullURL = URL(string: fullPath) else { return }

        KingfisherManager.shared.retrieveImage(with: fullURL) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let imageResult):
                Task { @MainActor in
                    self.updatePhotoUploadButton(with: imageResult.image)
                }
            case .failure:
                break
            }
        }
    }

    private func handleSaveSuccess(filterDetail: FilterDetail) {

        if mode.isEditMode {
            // 수정 모드: 업데이트된 데이터 전달 후 이전 화면으로 돌아가기
            onUpdateComplete?(filterDetail)
            navigationController?.popViewController(animated: true)
        } else {
            // 생성 모드: Feed에 새 필터 알림 후 상세 화면으로 이동
            NotificationCenter.default.post(
                name: .filterDidCreate,
                object: nil,
                userInfo: ["filter": filterDetail]
            )
            navigateToFilterDetail(filterDetail: filterDetail)
        }
    }

    private func scrollToVisible(_ view: UIView, animated: Bool = true) {
        let rect = view.convert(view.bounds, to: scrollView)
        let targetRect = rect.insetBy(dx: 0, dy: -Layout.labelSpacing)
        scrollView.scrollRectToVisible(targetRect, animated: animated)
    }

    @objc private func categoryButtonTapped(_ sender: SelectableCapsuleButton) {
        categoryButtons.forEach { $0.isSelected = ($0 == sender) }
    }

    @objc private func saveButtonTapped() {
        // 1. Validate inputs
        let validationResult = validateInputs()

        switch validationResult {
        case .success(let validatedInput):
            // ViewModel로 입력값 전달
            let viewModelInput = FilterMakeViewModel.ValidatedFilterInput(
                title: validatedInput.title,
                category: validatedInput.category,
                description: validatedInput.description,
                price: validatedInput.price,
                filteredPhoto: filteredPhotoImage ?? validatedInput.photo,  // 필터 적용본 우선
                originalPhoto: originalPhotoImage ?? validatedInput.photo,   // 원본
                metadata: validatedInput.metadata,
                filterValues: currentFilterValues ?? .default  // 실제 필터값 또는 기본값
            )
            saveButtonTappedSubject.send(viewModelInput)

        case .failure(let error):
            showAlert(message: error.message)
        }
    }

    private func navigateToFilterDetail(filterDetail: FilterDetail) {
        let filterDetailVC = FilterDetailViewController(filterId: filterDetail.id)

        // 네비게이션 스택 정리: 현재 MakeVC를 새로운 빈 MakeVC로 교체
        // [RootVC, ..., MakeVC(filled)] -> [RootVC, ..., MakeVC(empty), DetailVC]
        // DetailVC에서 뒤로가기 시 빈 MakeVC로 돌아가서 새 게시글 작성 가능
        guard var viewControllers = navigationController?.viewControllers else {
            navigationController?.pushViewController(filterDetailVC, animated: true)
            return
        }

        // 현재 MakeVC (마지막 VC)를 새로운 빈 MakeVC로 교체
        viewControllers.removeLast()
        let newMakeVC = FilterMakeViewController(mode: .create)
        viewControllers.append(newMakeVC)
        // DetailVC 추가
        viewControllers.append(filterDetailVC)
        // 스택 교체 (애니메이션으로 DetailVC 표시)
        navigationController?.setViewControllers(viewControllers, animated: true)
    }

    @objc private func photoUploadButtonTapped() {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func backgroundTapped() {
        dismissKeyboard()
    }

    @objc private func photoEditButtonTapped() {
        // 원본 이미지 확인 (첫 편집: selectedPhotoImage, 재편집: originalPhotoImage)
        guard let imageToEdit = originalPhotoImage ?? selectedPhotoImage else { return }

        let viewController = FilterEditViewController(image: imageToEdit)

        // 콜백 설정
        viewController.onSaveComplete = { [weak self] filteredImage, originalImage, filterValues in
            guard let self else { return }

            // 데이터 저장
            self.originalPhotoImage = originalImage
            self.filteredPhotoImage = filteredImage
            self.currentFilterValues = filterValues

            // UI 업데이트 (필터 적용 이미지를 미리보기로 표시)
            self.updatePhotoUploadButton(with: filteredImage)
        }

        navigationController?.pushViewController(viewController, animated: true)
    }

    @objc private func priceTextFieldDidChange() {
        let digits = priceTextField.text?.filter { $0.isNumber } ?? ""
        if digits.isEmpty {
            priceTextField.text = nil
        } else {
            let formattedText = formatPriceText(from: digits)
            if priceTextField.text != formattedText {
                priceTextField.text = formattedText
            }
        }
    }

    private func formatPriceText(from digits: String) -> String {
        guard let value = Decimal(string: digits) else { return digits }
        return value.formatted(.number.grouping(.automatic))
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

    private func loadPhotoMetadata(
        using itemProvider: NSItemProvider,
        assetIdentifier: String?,
        fallbackImageSize: CGSize
    ) {
        let asset = fetchPhotoAsset(from: assetIdentifier)
        itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] fileURL, _ in
            guard let self else { return }
            let metadata = PhotoMetadataExtractor.makeMetadata(
                fileURL: fileURL,
                asset: asset,
                fallbackImageSize: fallbackImageSize
            )
            Task { @MainActor in
                self.updatePhotoMetadata(metadata)
            }
        }
    }

    private func fetchPhotoAsset(from assetIdentifier: String?) -> PHAsset? {
        guard let assetIdentifier else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject
    }

    @MainActor
    private func updatePhotoUploadButton(with image: UIImage) {

        selectedPhotoImage = image
        photoUploadButton.setBackgroundImage(nil, for: .normal)
        photoUploadButton.setImage(image, for: .normal)
        photoUploadButton.imageView?.contentMode = .scaleAspectFill
        photoUploadButton.contentHorizontalAlignment = .fill
        photoUploadButton.contentVerticalAlignment = .fill
        photoUploadButton.clipsToBounds = true

        applyPhotoSelectionLayout()
    }

    @MainActor
    private func applyPhotoSelectionLayout() {

        // 수정 모드가 아닐 때만 수정하기 버튼 표시
        if !mode.isEditMode {
            photoEditButton.isHidden = false
        } else {
        }

        metadataCell.isHidden = false
        photoUploadButtonHeightConstraint?.deactivate()
        photoUploadButtonSquareConstraint?.isActive = true

        view.layoutIfNeeded()
    }

    @MainActor
    private func updatePhotoMetadata(_ metadata: PhotoMetadata) {
        currentPhotoMetadata = metadata
        metadataCell.configure(metadata: metadata)
    }

    // MARK: - Validation
    private enum FilterValidationError: Error {
        case emptyFilterName
        case noSelectedCategory
        case emptyDescription
        case invalidPrice
        case noPhotoSelected

        var message: String {
            switch self {
            case .emptyFilterName:
                return "필터 이름을 입력해주세요."
            case .noSelectedCategory:
                return "카테고리를 선택해주세요."
            case .emptyDescription:
                return "필터 소개를 입력해주세요."
            case .invalidPrice:
                return "가격은 100원 이상이어야 합니다."
            case .noPhotoSelected:
                return "대표 사진을 선택해주세요."
            }
        }
    }

    private struct ValidatedFilterInput {
        let title: String
        let category: String
        let description: String
        let price: Int
        let photo: UIImage
        let metadata: PhotoMetadata
    }

    private func validateInputs() -> Result<ValidatedFilterInput, FilterValidationError> {
        // 1. Filter name validation
        guard let filterName = filterNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !filterName.isEmpty else {
            return .failure(.emptyFilterName)
        }

        // 2. Category validation
        guard let selectedCategory = categoryButtons.first(where: { $0.isSelected })?.titleLabel?.text else {
            return .failure(.noSelectedCategory)
        }

        // 3. Description validation
        guard let description = descriptionTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty else {
            return .failure(.emptyDescription)
        }

        // 4. Price validation (100원 이상)
        guard let priceText = priceTextField.text?.filter({ $0.isNumber }),
              !priceText.isEmpty,
              let price = Int(priceText),
              price >= 100 else {
            return .failure(.invalidPrice)
        }

        // 5. Photo validation (수정 모드에서는 기존 이미지 사용, 새 사진 불필요)
        let photo: UIImage
        if mode.isEditMode {
            // 수정 모드: 기존 이미지가 있으면 사용, 없으면 더미 이미지 (실제 업로드하지 않음)
            photo = selectedPhotoImage ?? UIImage()
        } else {
            // 생성 모드: 사진 필수
            guard let selectedPhoto = selectedPhotoImage else {
                return .failure(.noPhotoSelected)
            }
            photo = selectedPhoto
        }

        // 6. Metadata (use .empty if not extracted)
        let metadata = currentPhotoMetadata ?? .empty

        return .success(ValidatedFilterInput(
            title: filterName,
            category: selectedCategory,
            description: description,
            price: price,
            photo: photo,
            metadata: metadata
        ))
    }

    private func showAlert(message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension FilterMakeViewController {
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: scrollView)
        if isTouchInsideTextFields(at: location) {
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

    private func isTouchInsideTextFields(at location: CGPoint) -> Bool {
        let fields = [filterNameTextField, descriptionTextField, priceTextField]
        return fields.contains { field in
            let fieldFrame = field.convert(field.bounds, to: scrollView)
            return fieldFrame.contains(location)
        }
    }
}

// MARK: - UITextFieldDelegate
extension FilterMakeViewController: UITextFieldDelegate {
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
extension FilterMakeViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first,
              result.itemProvider.canLoadObject(ofClass: UIImage.self) else {
            return
        }

        let itemProvider = result.itemProvider
        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            Task { @MainActor in
                // 원본 저장 추가
                self.originalPhotoImage = image
                self.selectedPhotoImage = image
                self.updatePhotoUploadButton(with: image)
            }
            self.loadPhotoMetadata(
                using: itemProvider,
                assetIdentifier: result.assetIdentifier,
                fallbackImageSize: image.size
            )
        }
    }
}

private enum PhotoMetadataExtractor {
    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func makeMetadata(
        fileURL: URL?,
        asset: PHAsset?,
        fallbackImageSize: CGSize
    ) -> PhotoMetadata {
        var camera = "-"
        var lensInfo = ""
        var focalLength = 0
        var aperture = 0.0
        var iso = 0
        var shutterSpeed = "-"
        var pixelWidth = 0
        var pixelHeight = 0
        var fileSizeBytes = 0
        var takenDate: Date?
        var latitude: Double?
        var longitude: Double?

        if let fileURL, let properties = metadataProperties(from: fileURL) {
            let tiffDictionary = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            let exifDictionary = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
            let exifAuxDictionary = properties[kCGImagePropertyExifAuxDictionary] as? [CFString: Any]
            let gpsDictionary = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]

            let make = sanitizedString(tiffDictionary?[kCGImagePropertyTIFFMake])
            let model = sanitizedString(tiffDictionary?[kCGImagePropertyTIFFModel])
            let cameraParts = [make, model].compactMap { $0 }
            camera = cameraParts.isEmpty ? "-" : cameraParts.joined(separator: " ")

            lensInfo = sanitizedString(exifDictionary?[kCGImagePropertyExifLensModel])
                ?? sanitizedString(exifAuxDictionary?[kCGImagePropertyExifAuxLensModel])
                ?? ""

            focalLength = intValue(exifDictionary?[kCGImagePropertyExifFocalLength])
            aperture = doubleValue(exifDictionary?[kCGImagePropertyExifFNumber])
            iso = isoValue(exifDictionary?[kCGImagePropertyExifISOSpeedRatings])
            shutterSpeed = formatExposureTime(doubleValue(exifDictionary?[kCGImagePropertyExifExposureTime]))

            pixelWidth = intValue(properties[kCGImagePropertyPixelWidth])
            pixelHeight = intValue(properties[kCGImagePropertyPixelHeight])
            fileSizeBytes = fileSizeBytesValue(for: fileURL)

            if let dateString = sanitizedString(exifDictionary?[kCGImagePropertyExifDateTimeOriginal])
                ?? sanitizedString(tiffDictionary?[kCGImagePropertyTIFFDateTime]) {
                takenDate = exifDateFormatter.date(from: dateString)
            }

            if let gpsDictionary {
                let latitudeValue = optionalDoubleValue(gpsDictionary[kCGImagePropertyGPSLatitude])
                let latitudeReference = sanitizedString(gpsDictionary[kCGImagePropertyGPSLatitudeRef])
                let longitudeValue = optionalDoubleValue(gpsDictionary[kCGImagePropertyGPSLongitude])
                let longitudeReference = sanitizedString(gpsDictionary[kCGImagePropertyGPSLongitudeRef])
                latitude = signedCoordinate(value: latitudeValue, reference: latitudeReference)
                longitude = signedCoordinate(value: longitudeValue, reference: longitudeReference)
            }
        }

        if let asset {
            if pixelWidth == 0 { pixelWidth = asset.pixelWidth }
            if pixelHeight == 0 { pixelHeight = asset.pixelHeight }
            if takenDate == nil { takenDate = asset.creationDate }
            if latitude == nil || longitude == nil, let location = asset.location {
                latitude = location.coordinate.latitude
                longitude = location.coordinate.longitude
            }
        }

        if pixelWidth == 0 || pixelHeight == 0 {
            let fallbackWidth = Int(fallbackImageSize.width)
            let fallbackHeight = Int(fallbackImageSize.height)
            if fallbackWidth > 0 && fallbackHeight > 0 {
                pixelWidth = fallbackWidth
                pixelHeight = fallbackHeight
            }
        }

        let resolution = pixelWidth > 0 && pixelHeight > 0
        ? "\(pixelWidth) x \(pixelHeight)"
        : "-"
        let fileSize = fileSizeBytes > 0
        ? String(format: "%.1fMB", Double(fileSizeBytes) / 1_000_000)
        : "-"

        return PhotoMetadata(
            camera: camera,
            lensInfo: lensInfo,
            focalLength: focalLength,
            aperture: aperture,
            iso: iso,
            shutterSpeed: shutterSpeed,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            fileSizeBytes: fileSizeBytes,
            resolution: resolution,
            fileSize: fileSize,
            takenDate: takenDate,
            latitude: latitude,
            longitude: longitude
        )
    }

    private static func metadataProperties(from fileURL: URL) -> [CFString: Any]? {
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return nil
        }
        return properties
    }

    private static func fileSizeBytesValue(for fileURL: URL) -> Int {
        let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        return resourceValues?.fileSize ?? 0
    }

    private static func sanitizedString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func intValue(_ value: Any?) -> Int {
        if let intValue = value as? Int {
            return intValue
        }
        if let doubleValue = value as? Double {
            return Int(doubleValue.rounded())
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return 0
    }

    private static func doubleValue(_ value: Any?) -> Double {
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let intValue = value as? Int {
            return Double(intValue)
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return 0
    }

    private static func optionalDoubleValue(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let intValue = value as? Int {
            return Double(intValue)
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return nil
    }

    private static func isoValue(_ value: Any?) -> Int {
        if let isoValues = value as? [Double], let first = isoValues.first {
            return Int(first.rounded())
        }
        if let isoValues = value as? [Int], let first = isoValues.first {
            return first
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return 0
    }

    private static func formatExposureTime(_ exposureTime: Double) -> String {
        guard exposureTime > 0 else { return "-" }
        if exposureTime >= 1 {
            return String(format: "%.1fs", exposureTime)
        }
        let denominator = Int(round(1 / exposureTime))
        return "1/\(max(denominator, 1))"
    }

    private static func signedCoordinate(value: Double?, reference: String?) -> Double? {
        guard let value else { return nil }
        guard let reference else { return value }
        let uppercased = reference.uppercased()
        if uppercased == "S" || uppercased == "W" {
            return -value
        }
        return value
    }
}
