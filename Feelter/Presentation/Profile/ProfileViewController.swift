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
        static let backgroundHeight: CGFloat = 280
        static let infoBottomInset: CGFloat = 20
        static let filterCountSize: CGFloat = 84
        static let filterItemSize = CGSize(width: 140, height: 96)
        static let filterItemSpacing: CGFloat = 12
        static let tagSpacing: CGFloat = 8
        static let tagRowHeight: CGFloat = 34
        static let messageButtonSize: CGFloat = 44
        static let menuWidthRatio: CGFloat = 0.33
        static let menuItemHeight: CGFloat = 44
        static let menuItemSpacing: CGFloat = 12
        static let menuHorizontalInset: CGFloat = 12
    }

    private var filters: [FilterSummary] = []
    private var hashTags: [String] = []
    private var profileUserId: String?
    private var isMenuVisible = false
    private var menuTrailingConstraint: Constraint?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let backgroundImageView = UIImageView()
    private let backgroundDimView = UIView()
    private let nameLabel = UILabel()
    private let introductionLabel = UILabel()
    private let filterCountView = UIView()
    private let filterCountLabel = UILabel()
    private let filterCountTitleLabel = UILabel()
    private let filterSectionStackView = UIStackView()
    private let tagRowStackView = UIStackView()
    private let messageButton = UIButton(type: .system)
    private let menuOverlayView = UIView()
    private let menuContainerView = UIView()
    private let menuStackView = UIStackView()
    private let editProfileButton = FeelterButton(title: "프로필 수정")
    private let logoutButton = FeelterButton(title: "로그아웃")

    private lazy var infoStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, introductionLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        return stackView
    }()

    private lazy var filtersCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = Layout.filterItemSpacing
        layout.itemSize = Layout.filterItemSize

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            ProfileFilterCell.self,
            forCellWithReuseIdentifier: ProfileFilterCell.identifier
        )
        return collectionView
    }()

    private lazy var tagCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = Layout.tagSpacing
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.register(
            ProfileTagCell.self,
            forCellWithReuseIdentifier: ProfileTagCell.identifier
        )
        return collectionView
    }()

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

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(backgroundImageView)
        backgroundImageView.addSubview(backgroundDimView)
        backgroundImageView.addSubview(infoStackView)
        contentView.addSubview(filterSectionStackView)
        contentView.addSubview(tagRowStackView)

        filterSectionStackView.addArrangedSubview(filterCountView)
        filterSectionStackView.addArrangedSubview(filtersCollectionView)
        filterCountView.addSubview(filterCountLabel)
        filterCountView.addSubview(filterCountTitleLabel)

        tagRowStackView.addArrangedSubview(tagCollectionView)
        tagRowStackView.addArrangedSubview(messageButton)

        view.addSubview(menuOverlayView)
        menuOverlayView.addSubview(menuContainerView)
        menuContainerView.addSubview(menuStackView)
        menuStackView.addArrangedSubview(editProfileButton)
        menuStackView.addArrangedSubview(logoutButton)
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

        backgroundImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.backgroundHeight)
        }

        backgroundDimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        infoStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().inset(Layout.infoBottomInset)
        }

        filterSectionStackView.snp.makeConstraints { make in
            make.top.equalTo(backgroundImageView.snp.bottom).offset(Layout.sectionSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        filterCountView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.filterCountSize)
        }

        filterCountLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.centerX.equalToSuperview()
        }

        filterCountTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(filterCountLabel.snp.bottom).offset(6)
            make.centerX.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview().inset(12)
        }

        filtersCollectionView.snp.makeConstraints { make in
            make.height.equalTo(Layout.filterItemSize.height)
        }

        tagRowStackView.snp.makeConstraints { make in
            make.top.equalTo(filterSectionStackView.snp.bottom).offset(Layout.sectionSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().inset(Layout.sectionSpacing)
        }

        tagCollectionView.snp.makeConstraints { make in
            make.height.equalTo(Layout.tagRowHeight)
        }

        messageButton.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.messageButtonSize)
        }

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
        scrollView.showsVerticalScrollIndicator = false
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.backgroundColor = .Feelter.gray90
        backgroundImageView.image = UIImage(named: "appIcon")

        backgroundDimView.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        nameLabel.font = TextStyle.Mulgyeol.body1
        nameLabel.textColor = .Feelter.gray0

        introductionLabel.font = TextStyle.Pretendard.caption1
        introductionLabel.textColor = .Feelter.gray30
        introductionLabel.numberOfLines = 0

        filterSectionStackView.axis = .horizontal
        filterSectionStackView.alignment = .center
        filterSectionStackView.spacing = Layout.sectionSpacing

        filterCountView.backgroundColor = .Feelter.deepTurquoise
        filterCountView.layer.cornerRadius = 12
        filterCountView.clipsToBounds = true

        filterCountLabel.font = TextStyle.Mulgyeol.body1
        filterCountLabel.textColor = .Feelter.gray0
        filterCountLabel.textAlignment = .center
        filterCountLabel.text = "0"

        filterCountTitleLabel.font = TextStyle.Pretendard.body2
        filterCountTitleLabel.textColor = .Feelter.gray60
        filterCountTitleLabel.textAlignment = .center
        filterCountTitleLabel.text = "Filters"

        tagRowStackView.axis = .horizontal
        tagRowStackView.alignment = .center
        tagRowStackView.spacing = Layout.sectionSpacing

        tagCollectionView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tagCollectionView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        messageButton.backgroundColor = .Feelter.brightTurquoise
        messageButton.tintColor = .Feelter.gray0
        messageButton.layer.cornerRadius = Layout.messageButtonSize / 2
        messageButton.clipsToBounds = true
        messageButton.setImage(UIImage.Icon.message, for: .normal)
        messageButton.addTarget(self, action: #selector(handleMessageButtonTapped), for: .touchUpInside)

        menuOverlayView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        menuOverlayView.isHidden = true
        menuOverlayView.alpha = 0

        menuContainerView.backgroundColor = .Feelter.deepTurquoise

        menuStackView.axis = .vertical
        menuStackView.spacing = Layout.menuItemSpacing
        menuStackView.alignment = .fill

        editProfileButton.backgroundColor = .Feelter.brightTurquoise
        logoutButton.backgroundColor = .Feelter.deepTurquoise

        title = "프로필"

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
        title = user.nickname
        profileUserId = user.id
        nameLabel.text = user.name ?? user.nickname

        if let introduction = user.introduction, !introduction.isEmpty {
            introductionLabel.text = introduction
            introductionLabel.isHidden = false
        } else {
            introductionLabel.text = nil
            introductionLabel.isHidden = true
        }

        backgroundImageView.image = UIImage(named: "appIcon")
        backgroundImageView.backgroundColor = .clear
        if user.hasProfileImage, let path = user.profileImageURL {
            backgroundImageView.setFeelterImage(with: path)
        }

        hashTags = user.hashTags
        tagCollectionView.reloadData()
    }

    private func applyFilters(_ filters: [FilterSummary]) {
        self.filters = filters
        filterCountLabel.text = "\(filters.count)"
        filtersCollectionView.reloadData()
        filtersCollectionView.setContentOffset(.zero, animated: false)
    }

    @objc private func handleMessageButtonTapped() {
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
            // ViewModel에게 "확인 버튼 눌렀어" 신호 전달
            self?.logoutConfirmSubject.send(())
        })

        present(alert, animated: true)
    }

    private func showAlert(message: String) {
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
        if collectionView === filtersCollectionView {
            return filters.count
        }
        return hashTags.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if collectionView === filtersCollectionView {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ProfileFilterCell.identifier,
                for: indexPath
            ) as? ProfileFilterCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: filters[indexPath.item])
            return cell
        }

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
