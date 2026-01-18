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

final class SearchViewController: BaseViewController {

    weak var coordinator: SearchCoordinator?

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let topBarHeight: CGFloat = 44
        static let logoSize: CGFloat = 28
        static let searchFieldHeight: CGFloat = 36
        static let searchButtonSize: CGFloat = 32
        static let sectionSpacing: CGFloat = 12
        static let sliderHeight: CGFloat = 28
        static let tableBottomInset: CGFloat = 100
    }

    private struct DistanceOption {
        let title: String
        let maxDistance: Int?
    }

    private let distanceOptions: [DistanceOption] = [
        DistanceOption(title: "100m", maxDistance: 100),
        DistanceOption(title: "300m", maxDistance: 300),
        DistanceOption(title: "500m", maxDistance: 500),
        DistanceOption(title: "1km", maxDistance: 1_000),
        DistanceOption(title: "3km", maxDistance: 3_000),
        DistanceOption(title: "5km", maxDistance: 5_000),
        DistanceOption(title: "전체", maxDistance: nil)
    ]

    private let viewModel: SearchViewModel
    private var cancellables = Set<AnyCancellable>()

    private let topBarContainerView = UIView()
    private let logoImageView = UIImageView()
    private let searchTextField = UITextField()
    private let searchButton = UIButton(type: .system)

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private let distanceHeaderView = UIView()
    private let distanceTitleLabel = UILabel()
    private let distanceValueLabel = UILabel()
    private let distanceSlider = UISlider()

    private var posts: [SearchPostItem] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    private var currentDistanceIndex = 0

    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let refreshSubject = PassthroughSubject<Void, Never>()
    private let loadMoreSubject = PassthroughSubject<Void, Never>()
    private let searchRequestedSubject = PassthroughSubject<String, Never>()
    private let distanceChangedSubject = PassthroughSubject<Int?, Never>()
    private let locationUpdatedSubject = PassthroughSubject<CLLocationCoordinate2D, Never>()
    private let likeButtonTappedSubject = PassthroughSubject<(postId: String, isLiked: Bool), Never>()

    private let locationManager = CLLocationManager()
    private var hasReceivedInitialLocation = false

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
        viewDidLoadSubject.send(())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(topBarContainerView)
        view.addSubview(distanceHeaderView)
        view.addSubview(tableView)

        topBarContainerView.addSubview(logoImageView)
        topBarContainerView.addSubview(searchTextField)
        topBarContainerView.addSubview(searchButton)

        distanceHeaderView.addSubview(distanceTitleLabel)
        distanceHeaderView.addSubview(distanceValueLabel)
        distanceHeaderView.addSubview(distanceSlider)
    }

    override func configureLayout() {
        super.configureLayout()
        topBarContainerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(Layout.sectionSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.topBarHeight)
        }

        logoImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(Layout.logoSize)
        }

        searchButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(Layout.searchButtonSize)
        }

        searchTextField.snp.makeConstraints { make in
            make.leading.equalTo(logoImageView.snp.trailing).offset(Layout.sectionSpacing)
            make.trailing.equalTo(searchButton.snp.leading).offset(-Layout.sectionSpacing)
            make.centerY.equalToSuperview()
            make.height.equalTo(Layout.searchFieldHeight)
        }

        distanceHeaderView.snp.makeConstraints { make in
            make.top.equalTo(topBarContainerView.snp.bottom).offset(Layout.sectionSpacing)
            make.leading.trailing.equalToSuperview()
        }

        distanceTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Layout.sectionSpacing)
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
        }

        distanceValueLabel.snp.makeConstraints { make in
            make.centerY.equalTo(distanceTitleLabel)
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.leading.greaterThanOrEqualTo(distanceTitleLabel.snp.trailing).offset(Layout.sectionSpacing)
        }

        distanceSlider.snp.makeConstraints { make in
            make.top.equalTo(distanceTitleLabel.snp.bottom).offset(Layout.sectionSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.sliderHeight)
            make.bottom.equalToSuperview().inset(Layout.sectionSpacing)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(distanceHeaderView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func configureView() {
        super.configureView()
        view.backgroundColor = .Feelter.gray100

        logoImageView.image = UIImage(named: "appIcon")
        logoImageView.contentMode = .scaleAspectFit

        searchTextField.delegate = self
        searchTextField.placeholder = "검색어를 입력하세요"
        searchTextField.font = TextStyle.Pretendard.body2
        searchTextField.textColor = .Feelter.gray15
        searchTextField.backgroundColor = .Feelter.blackTurquoise
        searchTextField.layer.cornerRadius = Radius.m
        searchTextField.layer.borderWidth = 1
        searchTextField.layer.borderColor = UIColor.Feelter.gray75?.cgColor
        searchTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        searchTextField.leftViewMode = .always
        searchTextField.clearButtonMode = .whileEditing
        searchTextField.returnKeyType = .search

        searchButton.setImage(UIImage.TabBar.searchEmpty, for: .normal)
        searchButton.tintColor = .Feelter.gray15
        searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
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
        distanceHeaderView.backgroundColor = .Feelter.gray100

        distanceTitleLabel.text = "반경"
        distanceTitleLabel.font = TextStyle.Pretendard.body2
        distanceTitleLabel.textColor = .Feelter.gray15

        distanceValueLabel.font = TextStyle.Pretendard.body2
        distanceValueLabel.textColor = .Feelter.gray60
        distanceValueLabel.textAlignment = .right

        distanceSlider.minimumValue = 0
        distanceSlider.maximumValue = Float(distanceOptions.count - 1)
        distanceSlider.isContinuous = true
        distanceSlider.minimumTrackTintColor = .Feelter.deepTurquoise
        distanceSlider.maximumTrackTintColor = .Feelter.gray75
        distanceSlider.addTarget(self, action: #selector(distanceSliderChanged(_:)), for: .valueChanged)
    }

    private func applyDistanceSelection(index: Int, shouldNotify: Bool) {
        guard index >= 0, index < distanceOptions.count else { return }
        currentDistanceIndex = index
        let option = distanceOptions[index]
        distanceValueLabel.text = option.title
        distanceSlider.setValue(Float(index), animated: false)
        if shouldNotify {
            distanceChangedSubject.send(option.maxDistance)
        }
    }

    private func bind() {
        let input = SearchViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            refreshTriggered: refreshSubject.eraseToAnyPublisher(),
            loadMoreTriggered: loadMoreSubject.eraseToAnyPublisher(),
            searchRequested: searchRequestedSubject.eraseToAnyPublisher(),
            distanceChanged: distanceChangedSubject.eraseToAnyPublisher(),
            locationUpdated: locationUpdatedSubject.eraseToAnyPublisher(),
            likeButtonTapped: likeButtonTappedSubject.eraseToAnyPublisher()
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

    @objc private func handleRefresh() {
        refreshSubject.send(())
    }

    @objc private func searchButtonTapped() {
        searchRequestedSubject.send(searchTextField.text ?? "")
        view.endEditing(true)
    }

    @objc private func distanceSliderChanged(_ slider: UISlider) {
        let index = Int(round(slider.value))
        if index != currentDistanceIndex {
            applyDistanceSelection(index: index, shouldNotify: true)
        } else {
            slider.setValue(Float(index), animated: false)
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
        cell.configure(with: item)
        cell.onLikeTapped = { [weak self] postId, isLiked in
            self?.likeButtonTappedSubject.send((postId: postId, isLiked: isLiked))
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
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
        fallbackToAllPosts()
    }
}
