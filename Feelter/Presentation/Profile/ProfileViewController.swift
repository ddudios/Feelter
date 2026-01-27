//
//  ProfileViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit
import SnapKit
import Combine

final class ProfileViewController: BaseViewController {

    var onChatListTapped: (() -> Void)?
    var onMessageTapped: ((String) -> Void)?
    var onEditProfileTapped: (() -> Void)?

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let sectionSpacing: CGFloat = 16
        static let smallSpacing: CGFloat = 4

        // Profile Section
        static let profileImageWidthRatio: CGFloat = 2.0 / 3.0
        static let boxSpacing: CGFloat = 8
        static let boxCornerRadius: CGFloat = 12
        static let boxPadding: CGFloat = 12

        // HashTags
        static let tagSpacing: CGFloat = 8
        static let tagRowHeight: CGFloat = 34

        // Filter/Chat Box
        static let iconSize: CGFloat = 24

        // Category Filter
        static let filterItemSize = CGSize(width: 50, height: 50)
        static let filterItemSpacing: CGFloat = 8
        static let categoryLabelHeight: CGFloat = 25
        static let categoryBottomInset: CGFloat = 90

        // Menu
        static let menuWidthRatio: CGFloat = 0.33
        static let menuItemHeight: CGFloat = 44
        static let menuItemSpacing: CGFloat = 12
        static let menuHorizontalInset: CGFloat = 12
    }

    private var filters: [FilterSummary] = []
    private var filtersByCategory: [FilterCategory: [FilterSummary]] = [:]
    private let categories: [FilterCategory] = [.food, .portrait, .landscape, .night, .star]
    private var hashTags: [String] = []
    private var profileUserId: String?
    private var isMenuVisible = false
    private var menuTrailingConstraint: Constraint?

    // UI Components
    // HashTags Section
    private let hashTagsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = Layout.tagSpacing
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        return collectionView
    }()

    // Profile Section
    private let profileSectionView = UIView()
    private let profileImageView = UIImageView()
    private let rightBoxesStackView = UIStackView()
    private let filterBoxView = UIView()
    private let filterBoxIconView = UILabel()
    private let filterBoxCountLabel = UILabel()
    private let chatBoxView = UIView()
    private let chatBoxIconView = UIImageView()
    private let chatBoxLabel = UILabel()

    // Info Section
    private let nameLabel = UILabel()
    private let introductionLabel = UILabel()

    // Filter Scroll Section
    private let filterScrollView = UIScrollView()
    private let filterContainerView = UIView()

    // Category Labels (Bottom Fixed)
    private let categoryLabelsStackView = UIStackView()

    // Menu
    private let menuOverlayView = UIView()
    private let menuContainerView = UIView()
    private let menuStackView = UIStackView()
    private let editProfileButton = FeelterButton(title: "프로필 수정")
    private let logoutButton = FeelterButton(title: "로그아웃")


    private let viewModel: ProfileViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let logoutConfirmSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewDidLoadSubject.send(())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 프로필 수정 후 돌아왔을 때 업데이트된 내용 반영
        if isViewLoaded {
            viewDidLoadSubject.send(())
        }
    }

    override func configureHierarchy() {
        super.configureHierarchy()

        // Profile Section
        view.addSubview(profileSectionView)
        profileSectionView.addSubview(profileImageView)
        profileSectionView.addSubview(rightBoxesStackView)

        rightBoxesStackView.addArrangedSubview(filterBoxView)
        rightBoxesStackView.addArrangedSubview(chatBoxView)

        filterBoxView.addSubview(filterBoxIconView)
        filterBoxView.addSubview(filterBoxCountLabel)

        chatBoxView.addSubview(chatBoxIconView)
        chatBoxView.addSubview(chatBoxLabel)

        // Info Section
        view.addSubview(nameLabel)
        view.addSubview(hashTagsCollectionView)
        view.addSubview(introductionLabel)

        // Filter Scroll Section
        view.addSubview(filterScrollView)
        filterScrollView.addSubview(filterContainerView)

        // Category Labels (Bottom Fixed)
        view.addSubview(categoryLabelsStackView)

        // Menu
        view.addSubview(menuOverlayView)
        menuOverlayView.addSubview(menuContainerView)
        menuContainerView.addSubview(menuStackView)
        menuStackView.addArrangedSubview(editProfileButton)
        menuStackView.addArrangedSubview(logoutButton)

        // Register cells
        hashTagsCollectionView.dataSource = self
        hashTagsCollectionView.delegate = self
        hashTagsCollectionView.register(
            ProfileTagCell.self,
            forCellWithReuseIdentifier: ProfileTagCell.identifier
        )
    }

    override func configureLayout() {
        super.configureLayout()

        // Profile Section
        profileSectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(Layout.smallSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        profileImageView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(Layout.profileImageWidthRatio)
            make.height.equalTo(profileImageView.snp.width)
        }

        rightBoxesStackView.snp.makeConstraints { make in
            make.leading.equalTo(profileImageView.snp.trailing).offset(8)
            make.trailing.top.bottom.equalToSuperview()
        }

        // Filter Box (2/3 height)
        filterBoxView.snp.makeConstraints { make in
            make.height.equalTo(profileImageView.snp.height).multipliedBy(2.0 / 3.0).offset(-Layout.boxSpacing / 2)
        }

        // Chat Box (1/3 height)
        chatBoxView.snp.makeConstraints { make in
            make.height.equalTo(profileImageView.snp.height).multipliedBy(1.0 / 3.0).offset(-Layout.boxSpacing / 2)
        }

        // Filter Box
        filterBoxIconView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(Layout.boxPadding)
        }

        filterBoxCountLabel.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(Layout.boxPadding)
        }

        // Chat Box
        chatBoxIconView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(Layout.boxPadding)
            make.width.height.equalTo(Layout.iconSize)
        }

        chatBoxLabel.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(Layout.boxPadding)
        }

        // Info Section
        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(profileSectionView.snp.bottom).offset(8)
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
        }

        // HashTags (이름 옆에)
        hashTagsCollectionView.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(Layout.smallSpacing)
            make.centerY.equalTo(nameLabel)
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.tagRowHeight)
        }

        introductionLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(Layout.smallSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        // Category Labels
        categoryLabelsStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(Layout.categoryBottomInset)
            make.height.equalTo(Layout.categoryLabelHeight)
        }

        // Filter Scroll Section
        filterScrollView.snp.makeConstraints { make in
            make.top.equalTo(introductionLabel.snp.bottom).offset(Layout.smallSpacing)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(categoryLabelsStackView.snp.top)
        }

        filterContainerView.snp.makeConstraints { make in
            make.edges.equalTo(filterScrollView.contentLayoutGuide)
            make.width.equalTo(filterScrollView.frameLayoutGuide)
        }

        // Menu
        menuOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        menuContainerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(Layout.menuWidthRatio)
            menuTrailingConstraint = make.trailing.equalToSuperview().constraint
        }

        menuStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(120)
            make.leading.trailing.equalToSuperview().inset(Layout.menuHorizontalInset)
        }

        [editProfileButton, logoutButton].forEach { button in
            button.snp.makeConstraints { make in
                make.height.equalTo(Layout.menuItemHeight)
            }
        }
    }

    override func configureView() {
        super.configureView()

        // Navigation Inline Title
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        // Profile Image
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.backgroundColor = .Feelter.gray90
        profileImageView.layer.cornerRadius = Layout.boxCornerRadius

        // Right Boxes StackView
        rightBoxesStackView.axis = .vertical
        rightBoxesStackView.spacing = Layout.boxSpacing
        rightBoxesStackView.distribution = .fill

        // Filter Box
        filterBoxView.backgroundColor = .Feelter.deepTurquoise
        filterBoxView.layer.cornerRadius = Layout.boxCornerRadius
        filterBoxView.clipsToBounds = true

        filterBoxIconView.text = "Filter"
        filterBoxIconView.font = TextStyle.Pretendard.caption2
        filterBoxIconView.textColor = .Feelter.gray60

        filterBoxCountLabel.font = TextStyle.Mulgyeol.body1
        filterBoxCountLabel.textColor = .Feelter.gray0
        filterBoxCountLabel.textAlignment = .right
        filterBoxCountLabel.text = "0"

        // Chat Box
        chatBoxView.backgroundColor = .Feelter.brightTurquoise
        chatBoxView.layer.cornerRadius = Layout.boxCornerRadius
        chatBoxView.clipsToBounds = true
        let chatTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleChatBoxTapped))
        chatBoxView.addGestureRecognizer(chatTapGesture)
        chatBoxView.isUserInteractionEnabled = true

        chatBoxIconView.image = UIImage.Icon.message
        chatBoxIconView.tintColor = .Feelter.gray60
        chatBoxIconView.contentMode = .scaleAspectFit

        chatBoxLabel.text = "Chat"
        chatBoxLabel.font = TextStyle.Pretendard.body2
        chatBoxLabel.textColor = .Feelter.gray0
        chatBoxLabel.textAlignment = .right

        // Info Section
        nameLabel.font = TextStyle.Pretendard.body2
        nameLabel.textColor = .Feelter.gray0
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // HashTags CollectionView
        hashTagsCollectionView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hashTagsCollectionView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        introductionLabel.font = TextStyle.Pretendard.caption1
        introductionLabel.textColor = .Feelter.gray60
        introductionLabel.textAlignment = .left
        introductionLabel.numberOfLines = 0

        // Filter Scroll View
        filterScrollView.showsVerticalScrollIndicator = true
        filterScrollView.alwaysBounceVertical = true

        // Category Labels StackView
        categoryLabelsStackView.axis = .horizontal
        categoryLabelsStackView.distribution = .fillEqually
        categoryLabelsStackView.alignment = .center
        categoryLabelsStackView.spacing = 0

        // Create category labels
        for category in categories {
            let label = UILabel()
            label.text = category.rawValue
            label.font = TextStyle.Pretendard.body4
            label.textColor = .Feelter.gray0
            label.textAlignment = .center
            categoryLabelsStackView.addArrangedSubview(label)
        }

        // Menu
        menuOverlayView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        menuOverlayView.isHidden = true
        menuOverlayView.alpha = 0

        menuContainerView.backgroundColor = .Feelter.deepTurquoise

        menuStackView.axis = .vertical
        menuStackView.spacing = Layout.menuItemSpacing
        menuStackView.alignment = .fill

        editProfileButton.backgroundColor = .Feelter.brightTurquoise
        logoutButton.backgroundColor = .Feelter.deepTurquoise

        let overlayTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMenuOverlayTapped))
        overlayTapGesture.cancelsTouchesInView = true
        overlayTapGesture.delegate = self
        menuOverlayView.addGestureRecognizer(overlayTapGesture)

        if viewModel.isMyProfile {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "line.3.horizontal"),
                style: .plain,
                target: self,
                action: #selector(handleMenuButtonTapped)
            )
            navigationItem.rightBarButtonItem?.tintColor = .Feelter.gray75
        } else {
            navigationItem.rightBarButtonItem = nil
        }

        let input = ProfileViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            logoutButtonTapped: logoutButton.tapPublisher,
            logoutConfirmed: logoutConfirmSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.applyProfile(user)
            }
            .store(in: &cancellables)

        output.filters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filters in
                self?.applyFilters(filters)
            }
            .store(in: &cancellables)

        output.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let message, !message.isEmpty else { return }
                self?.showAlert(message: message)
            }
            .store(in: &cancellables)

        output.showLogoutAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.showLogoutAlert()
            }
            .store(in: &cancellables)

        output.logoutFinished
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.performLogout()
            }
            .store(in: &cancellables)

        editProfileButton.tapPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handleEditProfileTapped()
            }
            .store(in: &cancellables)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !isMenuVisible {
            updateMenuHiddenState()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideMenuIfNeeded(animated: false)
    }

    private func applyProfile(_ user: User) {
        profileUserId = user.id
        title = user.nickname
        nameLabel.text = user.name ?? user.nickname

        if let introduction = user.introduction, !introduction.isEmpty {
            introductionLabel.text = introduction
            introductionLabel.isHidden = false
        } else {
            introductionLabel.text = nil
            introductionLabel.isHidden = true
        }

        // Profile Image
        profileImageView.image = UIImage(named: "appIcon")
        profileImageView.backgroundColor = .Feelter.gray90
        if let path = user.profileImageURL, !path.isEmpty {
            let screenWidth = UIScreen.main.bounds.width
            let imageSize = screenWidth * Layout.profileImageWidthRatio - Layout.horizontalInset * 2
            profileImageView.setFeelterImage(
                with: path,
                targetSize: CGSize(width: imageSize, height: imageSize)
            )
        }

        // HashTags
        hashTags = user.hashTags
        hashTagsCollectionView.reloadData()
    }

    private func applyFilters(_ filters: [FilterSummary]) {
        self.filters = filters
        filterBoxCountLabel.text = "\(filters.count)"

        // 카테고리별로 필터 그룹핑
        filtersByCategory = Dictionary(grouping: filters, by: { $0.category })

        // 기존 필터 뷰 제거
        filterContainerView.subviews.forEach { $0.removeFromSuperview() }

        // 카테고리별 스택뷰 생성
        let categoryStackViews = categories.map { category -> UIStackView in
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = Layout.filterItemSpacing
            stackView.alignment = .center

            if let categoryFilters = filtersByCategory[category] {
                for filter in categoryFilters {
                    let imageView = UIImageView()
                    imageView.contentMode = .scaleAspectFill
                    imageView.clipsToBounds = true
                    imageView.backgroundColor = .Feelter.gray90
                    imageView.layer.cornerRadius = 8
                    imageView.setFeelterImage(with: filter.mainImageURL)
                    imageView.isUserInteractionEnabled = true

                    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleFilterImageTapped(_:)))
                    imageView.addGestureRecognizer(tapGesture)
                    imageView.tag = filters.firstIndex(where: { $0.id == filter.id }) ?? 0

                    stackView.addArrangedSubview(imageView)
                    imageView.snp.makeConstraints { make in
                        make.width.height.equalTo(Layout.filterItemSize.width)
                    }
                }
            }

            return stackView
        }

        // 가로 스택뷰로 카테고리들을 배치
        let horizontalStackView = UIStackView(arrangedSubviews: categoryStackViews)
        horizontalStackView.axis = .horizontal
        horizontalStackView.distribution = .fillEqually
        horizontalStackView.alignment = .bottom
        horizontalStackView.spacing = 0

        filterContainerView.addSubview(horizontalStackView)
        horizontalStackView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(Layout.horizontalInset)
            make.top.greaterThanOrEqualToSuperview().inset(Layout.horizontalInset)
        }
    }

    @objc private func handleFilterImageTapped(_ sender: UITapGestureRecognizer) {
        guard let imageView = sender.view as? UIImageView,
              imageView.tag < filters.count else { return }

        let filter = filters[imageView.tag]
        let filterDetailVC = FilterDetailViewController(filterId: filter.id)
        navigationController?.pushViewController(filterDetailVC, animated: true)
    }

    @objc private func handleChatBoxTapped() {
        if viewModel.isMyProfile {
            onChatListTapped?()
            return
        }

        guard let profileUserId, !profileUserId.isEmpty else {
            showAlert(message: "채팅을 시작할 수 없습니다.")
            return
        }
        onMessageTapped?(profileUserId)
    }

    @objc private func handleMenuButtonTapped() {
        isMenuVisible ? hideMenuIfNeeded(animated: true) : showMenu()
    }

    @objc private func handleMenuOverlayTapped(_ sender: UITapGestureRecognizer) {
        hideMenuIfNeeded(animated: true)
    }

    private func handleEditProfileTapped() {
        hideMenuIfNeeded(animated: true)
        onEditProfileTapped?()
    }

    private func showMenu() {
        menuOverlayView.isHidden = false
        menuOverlayView.alpha = 0
        menuTrailingConstraint?.update(offset: 0)
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.menuOverlayView.alpha = 1
            self.menuOverlayView.layoutIfNeeded()
        }
        isMenuVisible = true
    }

    private func hideMenuIfNeeded(animated: Bool) {
        guard isMenuVisible else { return }
        updateMenuHiddenState()
        let animations = {
            self.menuOverlayView.alpha = 0
            self.menuOverlayView.layoutIfNeeded()
        }

        let completion: (Bool) -> Void = { _ in
            self.menuOverlayView.isHidden = true
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn], animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }

        isMenuVisible = false
    }

    private func updateMenuHiddenState() {
        let menuWidth = view.bounds.width * Layout.menuWidthRatio
        menuTrailingConstraint?.update(offset: menuWidth)
    }

    private func showLogoutAlert() {
        let alert = UIAlertController(
            title: "로그아웃",
            message: "정말 로그아웃 하시겠습니까?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "로그아웃", style: .destructive) { [weak self] _ in
            self?.logoutConfirmSubject.send(())
        })

        present(alert, animated: true)
    }

    private func showAlert(message: String) {
        // 뷰가 윈도우에 올라와 있는지 확인 (detached view controller 방지)
        guard view.window != nil, isViewLoaded else { return }

        let alert = UIAlertController(
            title: "안내",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func performLogout() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate,
              let appCoordinator = sceneDelegate.appCoordinator else { return }
        appCoordinator.logout()
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension ProfileViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return hashTags.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ProfileTagCell.identifier,
            for: indexPath
        ) as? ProfileTagCell else {
            return UICollectionViewCell()
        }
        cell.configure(tag: hashTags[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionView Cells
private final class ProfileFilterCell: UICollectionViewCell {

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.backgroundColor = .Feelter.gray90
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }

    func configure(with filter: FilterSummary) {
        imageView.setFeelterImage(with: filter.mainImageURL)
    }
}

private final class ProfileTagCell: UICollectionViewCell {

    private let tagLabel = CapsuleLabel(padding: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        contentView.addSubview(tagLabel)
        tagLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tagLabel.font = TextStyle.Pretendard.caption1
        tagLabel.textColor = .Feelter.gray60
        tagLabel.backgroundColor = .Feelter.blackTurquoise
    }

    func configure(tag: String) {
        tagLabel.text = tag.hasPrefix("#") ? tag : "#\(tag)"
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ProfileViewController {
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer.view === menuOverlayView {
            if let touchedView = touch.view, touchedView.isDescendant(of: menuContainerView) {
                return false
            }
            return true
        }

        if touch.view is UIControl {
            return false
        }

        if touch.view is UITextView {
            return false
        }

        return true
    }
}
