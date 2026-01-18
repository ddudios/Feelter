//
//  HomeViewController.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import UIKit
import SnapKit
import Combine
import Kingfisher

final class HomeViewController: BaseViewController {

    weak var coordinator: HomeCoordinator?

    // MARK: - Types
    enum Section {
        case todayFilter
        case banner
        case hotTrend
    }

    struct IndexedFilter: Hashable {
        let filter: FilterSummary
        let index: Int

        static func == (lhs: IndexedFilter, rhs: IndexedFilter) -> Bool {
            lhs.filter.id == rhs.filter.id && lhs.index == rhs.index
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(filter.id)
            hasher.combine(index)
        }
    }

    enum Item: Hashable {
        case todayFilter(TodayFilter)
        case banner(Banner)
        case hotTrend(IndexedFilter)
    }

    private let viewModel: HomeViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let bannerTappedSubject = PassthroughSubject<Banner, Never>()
    private let hotTrendTappedSubject = PassthroughSubject<FilterSummary, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Components
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.delegate = self
        collectionView.register(TodayFilterCell.self, forCellWithReuseIdentifier: TodayFilterCell.identifier)
        collectionView.register(BannerCell.self, forCellWithReuseIdentifier: BannerCell.identifier)
        collectionView.register(HotTrendCell.self, forCellWithReuseIdentifier: HotTrendCell.identifier)
        collectionView.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderView.identifier
        )
        return collectionView
    }()

    private let pageIndicatorLabel = {
        let label = PaddingLabel()
        label.padding = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        label.font = TextStyle.Pretendard.body4
        label.textColor = .Feelter.gray45
        label.backgroundColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5)
        label.layer.borderColor = UIColor.Feelter.gray60?.withAlphaComponent(0.5).cgColor
        label.layer.borderWidth = 1
        label.clipsToBounds = true
        label.textAlignment = .center
        label.isHidden = false
        return label
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var totalBannerCount = 0
    private var currentBannerPage = 0
    private var bannerAutoScrollTimer: Timer?
    private let hotTrendLoopCount = 5
    private var hotTrendBaseCount = 0
    private var hotTrendMiddleStartIndex = 0
    private var isHotTrendRepositioning = false

    // MARK: - Initializer
    init(viewModel: HomeViewModel = DIContainer.shared.resolve(HomeViewModel.self)) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDataSource()
        bind()
        viewDidLoadSubject.send(())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startBannerAutoScroll()
        printAccessToken()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopBannerAutoScroll()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePageIndicatorPosition()
    }

    deinit {
        stopBannerAutoScroll()
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(collectionView)
        view.addSubview(pageIndicatorLabel)
    }

    override func configureLayout() {
        super.configureLayout()

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 커스텀 탭바와 겹치지 않도록 하단 여백 추가
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
    }

    // MARK: - Private Methods
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in

            if sectionIndex == 0 {
                // Section 0: TodayFilter - 화면 높이의 60%
                let screenHeight = environment.container.effectiveContentSize.height
                let todayFilterHeight = screenHeight * 0.6

                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(todayFilterHeight)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(todayFilterHeight)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                let section = NSCollectionLayoutSection(group: group)
                return section

            } else if sectionIndex == 1 {
                // Section 1: Banner - 가로 스크롤
                let screenHeight = environment.container.effectiveContentSize.height
                let bannerHeight = screenHeight * 0.13

                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(bannerHeight)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(bannerHeight)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                group.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)

                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                section.interGroupSpacing = 20
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 38, trailing: 0)

                // 가로 스크롤 시 페이지 업데이트
                section.visibleItemsInvalidationHandler = { [weak self] visibleItems, scrollOffset, environment in
                    guard let self = self, self.totalBannerCount > 0 else { return }

                    // 스크롤 오프셋으로 현재 페이지 계산
                    let containerWidth = environment.container.contentSize.width
                    let groupWidth = containerWidth // fractionalWidth(1.0)
                    let spacing: CGFloat = 20
                    let pageWidth = groupWidth + spacing

                    // 현재 페이지 번호 (0부터 시작하는 인덱스)
                    let pageIndex = max(0, min(Int(round(scrollOffset.x / pageWidth)), self.totalBannerCount - 1))

                    DispatchQueue.main.async {
                        self.currentBannerPage = pageIndex
                        self.pageIndicatorLabel.text = "\(pageIndex + 1) / \(self.totalBannerCount)"
                    }
                }

                return section

            } else {
                // Section 2: HotTrend - 캐러셀 (가로 스크롤)
                let screenHeight = environment.container.effectiveContentSize.height
                let hotTrendHeight = screenHeight * 0.35

                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(1.0)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupWidthRatio: CGFloat = 0.55  // 셀 너비: 화면의 55%
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(groupWidthRatio),
                    heightDimension: .absolute(hotTrendHeight)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                section.interGroupSpacing = 12  // 셀 간격: 12pt
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 40, trailing: 0)

                // 가로 스크롤 시 dimming 효과 적용
                section.visibleItemsInvalidationHandler = { [weak self] visibleItems, scrollOffset, environment in
                    guard let self = self else { return }

                    let containerWidth = environment.container.contentSize.width
                    let centerX = scrollOffset.x + (containerWidth / 2)
                    let maxDimmingAlpha = HotTrendCell.maximumDimmingAlpha
                    var closestItem: NSCollectionLayoutVisibleItem?
                    var minimumDistance = CGFloat.greatestFiniteMagnitude

                    for item in visibleItems {
                        guard let cell = self.collectionView.cellForItem(at: item.indexPath) as? HotTrendCell else {
                            continue
                        }

                        // 셀의 중심 X 좌표
                        let cellCenterX = item.center.x

                        // 화면 중앙과 셀 중앙의 거리
                        let distance = abs(centerX - cellCenterX)

                        // 기준값: 셀의 너비 (frame에서 가져오기)
                        let transitionDistance = item.frame.width

                        // 비율 계산 (0.0 ~ 1.0)
                        let ratio = min(distance / transitionDistance, 1.0)

                        // alpha 값 적용 (최대까지 어두워짐)
                        let dimmingAlpha = ratio * maxDimmingAlpha

                        cell.setDimming(alpha: dimmingAlpha)

                        if distance < minimumDistance {
                            minimumDistance = distance
                            closestItem = item
                        }
                    }

                    if let indexPath = closestItem?.indexPath {
                        self.recenterHotTrendIfNeeded(currentIndex: indexPath.item)
                    }
                }

                // 헤더 추가
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(44)
                )
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]

                return section
            }
        }
        return layout
    }

    private func printAccessToken() {
        let token = KeychainManager.shared.read(account: "accessToken")
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            switch item {
            case .todayFilter(let filter):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TodayFilterCell.identifier,
                    for: indexPath
                ) as? TodayFilterCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: filter)

                cell.onCategoryTapped = { [weak self] category in
                    self?.coordinator?.showCategoryRanking(initialCategory: category)
                }

                return cell

            case .banner(let banner):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: BannerCell.identifier,
                    for: indexPath
                ) as? BannerCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: banner)
                cell.onTap = { [weak self] tappedBanner in
                    self?.bannerTappedSubject.send(tappedBanner)
                }
                return cell

            case .hotTrend(let indexedFilter):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: HotTrendCell.identifier,
                    for: indexPath
                ) as? HotTrendCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: indexedFilter.filter)
                cell.onTap = { [weak self] tappedFilter in
                    self?.hotTrendTappedSubject.send(tappedFilter)
                }
                return cell
            }
        }

        // Supplementary View Provider (헤더)
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else {
                return nil
            }

            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SectionHeaderView.identifier,
                for: indexPath
            ) as? SectionHeaderView

            // Section 2 (HotTrend)에만 헤더 표시
            if indexPath.section == 2 {
                header?.configure(with: "핫 트렌드")
            }

            return header
        }

        // 초기 스냅샷: 모든 섹션을 순서대로 추가
        var initialSnapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        initialSnapshot.appendSections([.todayFilter, .banner, .hotTrend])
        dataSource.apply(initialSnapshot, animatingDifferences: false)
    }

    private func bind() {
        let input = HomeViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            bannerTapped: bannerTappedSubject.eraseToAnyPublisher(),
            hotTrendTapped: hotTrendTappedSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.todayFilter
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filter in
                self?.updateTodayFilter(with: filter)
            }
            .store(in: &cancellables)

        output.banners
            .receive(on: DispatchQueue.main)
            .sink { [weak self] banners in
                self?.updateBanners(with: banners)
            }
            .store(in: &cancellables)

        output.hotTrends
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filters in
                self?.updateHotTrends(with: filters)
            }
            .store(in: &cancellables)

        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { isLoading in
                // TODO: 로딩 인디케이터 처리
            }
            .store(in: &cancellables)

        output.errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showAlert(message: message)
            }
            .store(in: &cancellables)

        output.presentWebView
            .receive(on: DispatchQueue.main)
            .sink { [weak self] urlString in
                self?.presentWebViewController(urlString: urlString)
            }
            .store(in: &cancellables)

        output.presentFilterDetail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filterId in
                self?.coordinator?.showFilterDetail(filterId: filterId)
            }
            .store(in: &cancellables)
    }

    private func updateTodayFilter(with filter: TodayFilter) {
        var snapshot = dataSource.snapshot()

        // 기존 아이템 삭제 후 새로 추가
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .todayFilter))
        snapshot.appendItems([.todayFilter(filter)], toSection: .todayFilter)

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func updateBanners(with banners: [Banner]) {
        var snapshot = dataSource.snapshot()

        // 기존 아이템 삭제 후 새로 추가
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .banner))
        let bannerItems = banners.map { Item.banner($0) }
        snapshot.appendItems(bannerItems, toSection: .banner)

        totalBannerCount = banners.count
        pageIndicatorLabel.isHidden = banners.isEmpty
        pageIndicatorLabel.text = "1 / \(totalBannerCount)"

        dataSource.apply(snapshot, animatingDifferences: false)

        // 페이지 인디케이터 위치 업데이트 및 자동 스크롤 시작
        DispatchQueue.main.async {
            self.updatePageIndicatorPosition()
            self.startBannerAutoScroll()
        }
    }

    private func updateHotTrends(with filters: [FilterSummary]) {
        guard !filters.isEmpty else { return }

        hotTrendBaseCount = filters.count
        hotTrendMiddleStartIndex = hotTrendBaseCount * (hotTrendLoopCount / 2)
        isHotTrendRepositioning = false

        var snapshot = dataSource.snapshot()

        // 기존 아이템 삭제 후 새로 추가
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .hotTrend))

        // 무한 스크롤을 위한 데이터 복제 (고유한 index 부여)
        var indexedFilters: [IndexedFilter] = []

        // 원본 데이터를 여러 번 반복하여 양방향 무한 스크롤을 만든다
        for repeatIndex in 0..<hotTrendLoopCount {
            for (filterIndex, filter) in filters.enumerated() {
                let uniqueIndex = repeatIndex * filters.count + filterIndex
                indexedFilters.append(IndexedFilter(filter: filter, index: uniqueIndex))
            }
        }

        let hotTrendItems = indexedFilters.map { Item.hotTrend($0) }
        snapshot.appendItems(hotTrendItems, toSection: .hotTrend)

        dataSource.apply(snapshot, animatingDifferences: false)

        // 초기 스크롤 위치 설정 및 dimming 적용
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let initialIndexPath = IndexPath(item: self.hotTrendMiddleStartIndex, section: 2)
            self.collectionView.scrollToItem(at: initialIndexPath, at: .centeredHorizontally, animated: false)
            self.collectionView.layoutIfNeeded()
            self.applyHotTrendDimmingEffect()
        }
    }

    private func applyHotTrendDimmingEffect() {
        guard let hotTrendScrollView = findHotTrendScrollView() else { return }

        let centerX = hotTrendScrollView.contentOffset.x + (hotTrendScrollView.bounds.width / 2)
        let maxDimmingAlpha = HotTrendCell.maximumDimmingAlpha

        let visibleCells = collectionView.visibleCells.compactMap { cell -> HotTrendCell? in
            guard let hotTrendCell = cell as? HotTrendCell,
                  let indexPath = collectionView.indexPath(for: hotTrendCell),
                  indexPath.section == 2 else {
                return nil
            }
            return hotTrendCell
        }

        for cell in visibleCells {
            guard let cellSuperview = cell.superview else { continue }
            let cellCenterX = hotTrendScrollView.convert(cell.center, from: cellSuperview).x
            let distance = abs(centerX - cellCenterX)
            let transitionDistance = cell.bounds.width
            let ratio = min(distance / transitionDistance, 1.0)
            cell.setDimming(alpha: ratio * maxDimmingAlpha)
        }
    }

    private func findHotTrendScrollView() -> UIScrollView? {
        for cell in collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell),
                  indexPath.section == 2 else { continue }
            var view: UIView? = cell
            while let superview = view?.superview {
                if let scrollView = superview as? UIScrollView, scrollView != collectionView {
                    return scrollView
                }
                view = superview
            }
        }
        return nil
    }

    private func recenterHotTrendIfNeeded(currentIndex: Int) {
        guard hotTrendBaseCount > 0 else { return }

        let totalItemCount = hotTrendBaseCount * hotTrendLoopCount
        guard totalItemCount > 0 else { return }

        let lowerBound = hotTrendBaseCount
        let upperBound = totalItemCount - hotTrendBaseCount - 1

        guard currentIndex < lowerBound || currentIndex > upperBound else { return }
        guard !isHotTrendRepositioning else { return }

        let indexInLoop = currentIndex % hotTrendBaseCount
        let targetIndex = hotTrendMiddleStartIndex + indexInLoop
        let targetIndexPath = IndexPath(item: targetIndex, section: 2)

        isHotTrendRepositioning = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if targetIndexPath.item < totalItemCount {
                self.collectionView.scrollToItem(at: targetIndexPath, at: .centeredHorizontally, animated: false)
                self.collectionView.layoutIfNeeded()
                self.applyHotTrendDimmingEffect()
            }
            self.isHotTrendRepositioning = false
        }
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func presentWebViewController(urlString: String) {
        let webViewController = WebViewController(urlString: urlString)
        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

    private func updatePageIndicatorPosition() {
        guard pageIndicatorLabel.superview != nil, totalBannerCount > 0 else { return }

        // 배너 섹션의 첫 번째 아이템 위치를 직접 구함
        let bannerIndexPath = IndexPath(item: 0, section: 1)
        guard let attributes = collectionView.layoutAttributesForItem(at: bannerIndexPath) else { return }

        // collectionView 좌표계에서 view 좌표계로 변환
        let bannerFrameInView = collectionView.convert(attributes.frame, to: view)

        // 인디케이터를 배너 우측 하단에 배치
        pageIndicatorLabel.snp.remakeConstraints { make in
            make.trailing.equalTo(view.snp.leading).offset(bannerFrameInView.maxX - 16)
            make.bottom.equalTo(view.snp.top).offset(bannerFrameInView.maxY - 10)
        }

        pageIndicatorLabel.layoutIfNeeded()
        pageIndicatorLabel.layer.cornerRadius = pageIndicatorLabel.bounds.height / 2
    }

    // MARK: - Banner Auto Scroll
    private func startBannerAutoScroll() {
        guard totalBannerCount > 1 else { return }
        stopBannerAutoScroll()
        bannerAutoScrollTimer = Timer.scheduledTimer(
            timeInterval: 5.0,
            target: self,
            selector: #selector(autoScrollBanner),
            userInfo: nil,
            repeats: true
        )
    }

    private func stopBannerAutoScroll() {
        bannerAutoScrollTimer?.invalidate()
        bannerAutoScrollTimer = nil
    }

    @objc private func autoScrollBanner() {
        guard totalBannerCount > 0 else { return }
        currentBannerPage += 1
        if currentBannerPage >= totalBannerCount {
            currentBannerPage = 0
        }
        scrollToBannerPage(currentBannerPage, animated: true)
    }

    private func scrollToBannerPage(_ page: Int, animated: Bool) {
        guard page < totalBannerCount else { return }

        // orthogonalScrollingBehavior를 사용하는 섹션은 내부 UIScrollView를 찾아서 스크롤
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 섹션의 가로 스크롤 오프셋 계산
            let containerWidth = self.collectionView.bounds.width
            let spacing: CGFloat = 20
            let targetX = CGFloat(page) * (containerWidth + spacing)

            // orthogonal scrolling 섹션 내부의 스크롤 뷰 찾기
            for subview in self.collectionView.subviews {
                if let scrollView = subview as? UIScrollView,
                   scrollView != self.collectionView {
                    let targetOffset = CGPoint(x: targetX, y: 0)
                    scrollView.setContentOffset(targetOffset, animated: animated)
                    return
                }
            }
        }
    }

    private func updateCurrentBannerPage() {
        guard let visibleCell = collectionView.visibleCells.first(where: { cell in
            guard let indexPath = collectionView.indexPath(for: cell) else { return false }
            return indexPath.section == 1
        }), let indexPath = collectionView.indexPath(for: visibleCell) else {
            return
        }
        currentBannerPage = indexPath.item
    }
}

// MARK: - UICollectionViewDelegate
extension HomeViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 세로 스크롤 시 페이지 인디케이터도 함께 이동
        updatePageIndicatorPosition()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        switch item {
        case .banner(let banner):
            bannerTappedSubject.send(banner)
        case .todayFilter:
            break
        case .hotTrend(let indexedFilter):
            hotTrendTappedSubject.send(indexedFilter.filter)
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        stopBannerAutoScroll()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateCurrentBannerPage()
            startBannerAutoScroll()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateCurrentBannerPage()
        startBannerAutoScroll()
    }
}
