//
//  SearchViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit
import SnapKit
import Combine
import CoreLocation
import AVKit
import AVFoundation

final class SearchViewController: BaseViewController {

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let topBarHeight: CGFloat = 44
        static let topBarToTableSpacing: CGFloat = 4
        static let logoSize: CGFloat = 80
        static let searchFieldHeight: CGFloat = 36
        static let searchButtonSize: CGFloat = 32
        static let sectionSpacing: CGFloat = 12
        static let sliderHeight: CGFloat = 28
        static let tableBottomInset: CGFloat = 100
        static let sliderPadding: CGFloat = 16
    }

    private struct DistanceOption {
        let title: String
        let maxDistance: Int?
    }

    private let distanceOptions: [DistanceOption] = [
        DistanceOption(title: "500m", maxDistance: 500),
        DistanceOption(title: "1km", maxDistance: 1_000),
        DistanceOption(title: "5km", maxDistance: 5_000),
        DistanceOption(title: "전체", maxDistance: nil)
    ]

    private let viewModel: SearchViewModel
    private var cancellables = Set<AnyCancellable>()
    weak var coordinator: SearchCoordinator?

    private let topBarContainerView = UIView()
    private let locationButton = UIButton(type: .system)
    private let searchTextField = UITextField()
    private let dimBackgroundView = UIView()

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private let distanceHeaderView = UIView()
    private let distanceBlurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let distanceSelectedTrack = UIView()
    private let distanceTitleLabel = UILabel()
    private let distanceValueLabel = UILabel()
    private let distanceSlider = UISlider()
    private let sliderStartGuide = UIView()
    private let sliderEndGuide = UIView()

    private var posts: [SearchPostItem] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    private var currentDistanceIndex = 0
    private var selectedTrackWidthConstraint: Constraint?
    private var isUpdatingSliderProgrammatically = false
    private var isDistancePopupVisible = false

    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let refreshSubject = PassthroughSubject<Void, Never>()
    private let loadMoreSubject = PassthroughSubject<Void, Never>()
    private let searchRequestedSubject = PassthroughSubject<String, Never>()
    private let distanceChangedSubject = PassthroughSubject<Int?, Never>()
    private let locationUpdatedSubject = PassthroughSubject<CLLocationCoordinate2D, Never>()
    private let likeButtonTappedSubject = PassthroughSubject<(postId: String, isLiked: Bool), Never>()
    private let deletePostSubject = PassthroughSubject<String, Never>()
    private let commentCountRefreshSubject = PassthroughSubject<String, Never>()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var hasReceivedInitialLocation = false

    private var currentUserId: String? {
        return KeychainManager.shared.read(account: "userId")
    }

    init(viewModel: SearchViewModel = DIContainer.shared.resolve(SearchViewModel.self)) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureLocation()
        configureTableView()
        configureTableHeaderView()
        bind()
        currentDistanceIndex = distanceOptions.count - 1
        applyDistanceSelection(index: currentDistanceIndex, shouldNotify: false)
        updateLocationButtonTitle()
        viewDidLoadSubject.send(())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(topBarContainerView)
        view.addSubview(tableView)

        topBarContainerView.addSubview(locationButton)
        topBarContainerView.addSubview(searchTextField)

        view.addSubview(dimBackgroundView)
        view.addSubview(distanceHeaderView)

        distanceHeaderView.addSubview(distanceBlurBackgroundView)
        distanceBlurBackgroundView.contentView.addSubview(distanceSelectedTrack)
        distanceBlurBackgroundView.contentView.addSubview(sliderStartGuide)
        distanceBlurBackgroundView.contentView.addSubview(sliderEndGuide)
        distanceBlurBackgroundView.contentView.addSubview(distanceTitleLabel)
        distanceBlurBackgroundView.contentView.addSubview(distanceValueLabel)
        distanceBlurBackgroundView.contentView.addSubview(distanceSlider)
    }

    override func configureLayout() {
        super.configureLayout()
        topBarContainerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(Layout.sectionSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.topBarHeight)
        }

        locationButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
        }

        searchTextField.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalTo(locationButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.height.equalTo(Layout.searchFieldHeight)
        }

        dimBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        distanceHeaderView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        distanceBlurBackgroundView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Layout.sectionSpacing)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }

        distanceSelectedTrack.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            selectedTrackWidthConstraint = make.width.equalTo(0).constraint
        }

        sliderStartGuide.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(1.0/3.0)
        }

        sliderEndGuide.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(5.0/6.0)
        }

        distanceTitleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(Layout.sliderPadding)
        }

        distanceValueLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(Layout.sliderPadding)
        }

        distanceSlider.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.height.equalToSuperview()
            make.leading.equalTo(sliderStartGuide.snp.trailing)
            make.trailing.equalTo(sliderEndGuide.snp.trailing)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(topBarContainerView.snp.bottom).offset(Layout.topBarToTableSpacing)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func configureView() {
        super.configureView()
        view.backgroundColor = .Feelter.gray100

        locationButton.setTitle(nil, for: .normal)
        locationButton.setImage(UIImage.Icon.pin, for: .normal)
        locationButton.tintColor = .Feelter.gray75
        locationButton.accessibilityLabel = "거리 필터"
        locationButton.contentHorizontalAlignment = .leading
        locationButton.contentEdgeInsets = .zero
        locationButton.titleEdgeInsets = .zero
        locationButton.setContentHuggingPriority(.required, for: .horizontal)
        locationButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        locationButton.addTarget(self, action: #selector(locationButtonTapped), for: .touchUpInside)

        dimBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        dimBackgroundView.isHidden = true
        dimBackgroundView.alpha = 0
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dimBackgroundTapped))
        dimBackgroundView.addGestureRecognizer(tapGesture)

        searchTextField.delegate = self
        searchTextField.placeholder = "검색어를 입력하세요"
        searchTextField.font = TextStyle.Pretendard.body2
        searchTextField.textColor = .Feelter.gray15
        searchTextField.backgroundColor = .Feelter.blackTurquoise
        searchTextField.layer.cornerRadius = Radius.m
        searchTextField.layer.borderWidth = 1
        searchTextField.layer.borderColor = UIColor.Feelter.gray75?.cgColor

        // leftView에 검색 아이콘 추가
        let leftContainer = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 36))
        let searchIconView = UIImageView(image: UIImage.TabBar.searchEmpty)
        searchIconView.tintColor = .Feelter.gray15
        searchIconView.contentMode = .scaleAspectFit
        searchIconView.frame = CGRect(x: 8, y: 8, width: 20, height: 20)
        leftContainer.addSubview(searchIconView)
        searchTextField.leftView = leftContainer
        searchTextField.leftViewMode = .always

        searchTextField.clearButtonMode = .whileEditing
        searchTextField.returnKeyType = .search
    }

    private func configureLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func configureTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 500
        tableView.rowHeight = UITableView.automaticDimension
        tableView.showsVerticalScrollIndicator = false
        tableView.register(SearchPostCell.self, forCellReuseIdentifier: SearchPostCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.refreshControl = refreshControl
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Layout.tableBottomInset, right: 0)

        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
    }

    private func configureTableHeaderView() {
        distanceHeaderView.backgroundColor = .clear
        distanceHeaderView.isHidden = true
        distanceHeaderView.alpha = 0

        distanceBlurBackgroundView.layer.cornerRadius = Radius.m
        distanceBlurBackgroundView.clipsToBounds = true

        distanceSelectedTrack.backgroundColor = UIColor.white.withAlphaComponent(0.2)

        sliderStartGuide.backgroundColor = .clear
        sliderStartGuide.isUserInteractionEnabled = false

        sliderEndGuide.backgroundColor = .clear
        sliderEndGuide.isUserInteractionEnabled = false

        distanceTitleLabel.text = "현재 위치 반경"
        distanceTitleLabel.font = TextStyle.Pretendard.body2
        distanceTitleLabel.textColor = .white

        distanceValueLabel.font = TextStyle.Pretendard.body2
        distanceValueLabel.textColor = .white
        distanceValueLabel.textAlignment = .right

        distanceSlider.minimumValue = 0
        distanceSlider.maximumValue = Float(distanceOptions.count - 1)
        distanceSlider.isContinuous = true
        distanceSlider.minimumTrackTintColor = .clear
        distanceSlider.maximumTrackTintColor = .clear
        distanceSlider.setThumbImage(createThumbImage(), for: .normal)
        distanceSlider.setThumbImage(createThumbImage(), for: .highlighted)
        distanceSlider.addTarget(self, action: #selector(distanceSliderChanged(_:)), for: .valueChanged)
    }

    private func createThumbImage() -> UIImage? {
        let width: CGFloat = 2
        let height: CGFloat = 40
        let size = CGSize(width: width, height: height)

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        UIColor.white.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private func applyDistanceSelection(index: Int, shouldNotify: Bool) {
        guard index >= 0, index < distanceOptions.count else { return }
        currentDistanceIndex = index
        let option = distanceOptions[index]
        distanceValueLabel.text = option.title
        updateLocationButtonTitle()
        isUpdatingSliderProgrammatically = true
        distanceSlider.setValue(Float(index), animated: false)
        isUpdatingSliderProgrammatically = false
        updateSelectedTrackWidth()
        if shouldNotify {
            distanceChangedSubject.send(option.maxDistance)
        }
    }

    private func updateLocationButtonTitle() {
        let locationName = distanceTitleLabel.text?.replacingOccurrences(of: " 반경", with: "") ?? "현재 위치"
        let distanceText = distanceValueLabel.text ?? "전체"
        locationButton.accessibilityValue = "\(locationName) 반경 \(distanceText)"
    }

    private func updateSelectedTrackWidth() {
        let sliderValue = distanceSlider.value
        // 원래 7개 옵션 중 2/6 ~ 5/6 범위에 매핑
        // value 0 (500m) → 1/3, value 3 (전체) → 5/6
        let percentage = 1.0/3.0 + CGFloat(sliderValue) / 6.0
        let totalWidth = distanceBlurBackgroundView.frame.width
        guard totalWidth > 0 else { return }
        let targetWidth = totalWidth * percentage
        selectedTrackWidthConstraint?.update(offset: targetWidth)
    }

    private func bind() {
        let input = SearchViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            refreshTriggered: refreshSubject.eraseToAnyPublisher(),
            loadMoreTriggered: loadMoreSubject.eraseToAnyPublisher(),
            searchRequested: searchRequestedSubject.eraseToAnyPublisher(),
            distanceChanged: distanceChangedSubject.eraseToAnyPublisher(),
            locationUpdated: locationUpdatedSubject.eraseToAnyPublisher(),
            likeButtonTapped: likeButtonTappedSubject.eraseToAnyPublisher(),
            deletePostRequested: deletePostSubject.eraseToAnyPublisher(),
            commentCountRefreshRequested: commentCountRefreshSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.posts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.posts = items
                self?.refreshControl.endRefreshing()
            }
            .store(in: &cancellables)

        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if !isLoading {
                    self?.refreshControl.endRefreshing()
                }
            }
            .store(in: &cancellables)

        output.errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.showErrorAlert(message: message)
            }
            .store(in: &cancellables)
    }

    private func showPostActionSheet(for item: SearchPostItem, sourceView: UIView) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "수정", style: .default) { [weak self] _ in
            self?.showEditPost(for: item)
        })
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.showDeleteConfirmation(for: item)
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))

        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sourceView
            popoverController.sourceRect = sourceView.bounds
            popoverController.permittedArrowDirections = .up
        }

        present(alert, animated: true)
    }

    private func showEditPost(for item: SearchPostItem) {
        let editContext = CreatePostViewModel.EditContext(
            postId: item.id,
            category: item.category,
            title: item.title,
            content: item.content,
            filePaths: item.imagePaths
        )

        if let coordinator {
            coordinator.showEditPost(context: editContext)
        } else {
            let postUsecase = DIContainer.shared.resolve(PostUsecaseProtocol.self)
            let viewModel = CreatePostViewModel(postUsecase: postUsecase, mode: .edit(editContext))
            let viewController = CreatePostViewController(viewModel: viewModel)
            navigationController?.pushViewController(viewController, animated: true)
        }
    }

    private func showDeleteConfirmation(for item: SearchPostItem) {
        let alert = UIAlertController(
            title: "게시글 삭제",
            message: "이 게시글을 삭제할까요?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.deletePostSubject.send(item.id)
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }

    private func updateLocationTitleLabel(for coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR")) { [weak self] placemarks, _ in
            guard let self else { return }
            let locationName = self.makeLocationName(from: placemarks?.first) ?? "현재 위치"
            Task { @MainActor in
                self.distanceTitleLabel.text = "\(locationName) 반경"
                self.updateLocationButtonTitle()
            }
        }
    }

    private func makeLocationName(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }
        if let subLocality = placemark.subLocality, !subLocality.isEmpty {
            return subLocality
        }
        if let locality = placemark.locality, !locality.isEmpty {
            return locality
        }
        if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
            return administrativeArea
        }
        return nil
    }

    @MainActor
    func refreshPosts() {
        refreshControl.beginRefreshing()
        refreshSubject.send(())
    }

    @objc private func handleRefresh() {
        refreshSubject.send(())
    }

    @objc private func locationButtonTapped() {
        toggleDistancePopup()
    }

    @objc private func dimBackgroundTapped() {
        hideDistancePopup()
    }

    private func toggleDistancePopup() {
        if isDistancePopupVisible {
            hideDistancePopup()
        } else {
            showDistancePopup()
        }
    }

    private func showDistancePopup() {
        isDistancePopupVisible = true
        dimBackgroundView.isHidden = false
        distanceHeaderView.isHidden = false

        view.bringSubviewToFront(dimBackgroundView)
        view.bringSubviewToFront(distanceHeaderView)

        UIView.animate(withDuration: 0.3) {
            self.dimBackgroundView.alpha = 1
            self.distanceHeaderView.alpha = 1
        }
    }

    private func hideDistancePopup() {
        isDistancePopupVisible = false

        UIView.animate(withDuration: 0.3) {
            self.dimBackgroundView.alpha = 0
            self.distanceHeaderView.alpha = 0
        } completion: { _ in
            self.dimBackgroundView.isHidden = true
            self.distanceHeaderView.isHidden = true
        }
    }

    @objc private func distanceSliderChanged(_ slider: UISlider) {
        guard !isUpdatingSliderProgrammatically else { return }
        let index = Int(round(slider.value))
        if index != currentDistanceIndex {
            applyDistanceSelection(index: index, shouldNotify: true)
            // 슬라이더 값이 변경되면 팝업 닫기
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.hideDistancePopup()
            }
        } else {
            updateSelectedTrackWidth()
        }
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "오류",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func showLocationPermissionAlert() {
        let alert = UIAlertController(
            title: "위치 권한 필요",
            message: "주변 게시글을 검색하려면 위치 권한이 필요합니다. 설정에서 위치 권한을 허용해주세요.\n\n권한을 허용하지 않으면 전체 게시글이 표시됩니다.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "설정으로 이동", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })

        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
            self?.fallbackToAllPosts()
        })

        present(alert, animated: true)
    }

    private func fallbackToAllPosts() {
        let allPostsIndex = distanceOptions.count - 1
        applyDistanceSelection(index: allPostsIndex, shouldNotify: true)
        distanceSlider.isEnabled = false
    }

    private func showCommentBottomSheet(for postId: String) {
        let commentVC = CommentBottomSheetViewController(postId: postId)
        commentVC.onCommentAdded = { [weak self] in
            self?.commentCountRefreshSubject.send(postId)
        }
        commentVC.modalPresentationStyle = .overFullScreen
        commentVC.modalTransitionStyle = .coverVertical

        present(commentVC, animated: true)
    }

    private func handleImageTapped(imagePaths: [String], tappedIndex: Int) {
        guard tappedIndex < imagePaths.count else { return }
        let tappedPath = imagePaths[tappedIndex]

        // 파일 확장자로 비디오 여부 확인
        let fileExtension = (tappedPath as NSString).pathExtension.lowercased()
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "m4v"]

        if videoExtensions.contains(fileExtension) {
            // 비디오 재생
            playVideo(urlString: tappedPath)
        } else {
            // 이미지 뷰어 표시
            showImageViewer(imagePaths: imagePaths, selectedIndex: tappedIndex)
        }
    }

    private func playVideo(urlString: String) {
        let finalURL = normalizedRemoteURL(from: urlString)

        guard let url = finalURL else {
            showErrorAlert(message: "비디오를 재생할 수 없습니다.")
            return
        }

        let playerItem = makePlayerItem(for: url)
        let player = AVPlayer(playerItem: playerItem)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player

        present(playerViewController, animated: true) {
            player.play()
        }
    }

    private func makePlayerItem(for url: URL) -> AVPlayerItem {
        if url.isFileURL {
            return AVPlayerItem(url: url)
        }

        var headers: [String: String] = [
            "SeSACKey": Config.apiKey
        ]
        if let accessToken = KeychainManager.shared.read(account: "accessToken"),
           !accessToken.isEmpty {
            headers["Authorization"] = accessToken
        }

        let asset = AVURLAsset(
            url: url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        return AVPlayerItem(asset: asset)
    }

    private func normalizedRemoteURL(from urlString: String) -> URL? {
        if let url = URL(string: urlString), url.scheme != nil {
            if url.path.hasPrefix("/data/") {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.path = "/v1" + url.path
                return components?.url
            }
            return url
        }

        let baseURLString = Config.baseURL.absoluteString
        let cleanedBase = baseURLString.hasSuffix("/") ? String(baseURLString.dropLast()) : baseURLString

        var path = urlString
        if path.hasPrefix("/data/") {
            path = "/v1" + path
        } else if path.hasPrefix("/v1/") {
            // 그대로 사용
        } else if path.hasPrefix("/") {
            path = "/v1" + path
        } else {
            path = "/v1/" + path
        }

        return URL(string: cleanedBase + path)
    }

    private func showImageViewer(imagePaths: [String], selectedIndex: Int) {
        // String 경로를 ChatImageSource.remote로 변환
        let imagesSources = imagePaths.map { ChatImageSource.remote($0) }

        // 기존 ImageViewerViewController 사용 (채팅방과 동일)
        let imageViewer = ImageViewerViewController(images: imagesSources, initialIndex: selectedIndex)
        imageViewer.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
        imageViewer.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        present(imageViewer, animated: true)
    }
}

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SearchPostCell.identifier,
            for: indexPath
        ) as? SearchPostCell else {
            return UITableViewCell()
        }

        let item = posts[indexPath.row]
        let isOwnedByCurrentUser = item.authorId == currentUserId
        cell.configure(with: item, isOwnedByCurrentUser: isOwnedByCurrentUser)
        cell.onLikeTapped = { [weak self] postId, isLiked in
            self?.likeButtonTappedSubject.send((postId: postId, isLiked: isLiked))
        }
        cell.onMoreTapped = { [weak self] postId, sourceView in
            guard let self = self,
                  let selectedItem = self.posts.first(where: { $0.id == postId }) else {
                return
            }
            self.showPostActionSheet(for: selectedItem, sourceView: sourceView)
        }
        cell.onCommentTapped = { [weak self] postId in
            self?.showCommentBottomSheet(for: postId)
        }
        cell.onImageTapped = { [weak self] imagePaths, tappedIndex in
            self?.handleImageTapped(imagePaths: imagePaths, tappedIndex: tappedIndex)
        }
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height

        guard contentHeight > frameHeight else { return }
        if offsetY > contentHeight - frameHeight - 200 {
            loadMoreSubject.send(())
        }
    }
}

extension SearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchRequestedSubject.send(textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }
}

extension SearchViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            showLocationPermissionAlert()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !hasReceivedInitialLocation else {
            return
        }
        guard let coordinate = locations.last?.coordinate else { return }
        hasReceivedInitialLocation = true
        locationUpdatedSubject.send(coordinate)
        updateLocationTitleLabel(for: coordinate)
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
        fallbackToAllPosts()
    }
}
