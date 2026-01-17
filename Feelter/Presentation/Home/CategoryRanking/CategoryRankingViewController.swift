//
//  CategoryRankingViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit
import Combine
import SnapKit

final class CategoryRankingViewController: BaseViewController {
    
    weak var coordinator: CategoryRankingCoordinator?

    // MARK: - Types
    enum Section {
        case category
        case topRanking
        case filterFeed
    }
    
    enum Item: Hashable {
        case category(FilterCategory)
        case topRanking(TopRankingLoopItem)
        case filterFeed(FilterSummary)
    }
    
    private enum TopRankingLayout {
        static let itemWidthFraction: CGFloat = 0.58
        static let groupHeight: CGFloat = 440
        static let interGroupSpacing: CGFloat = 12
        static let verticalOffset: CGFloat = 90
        static let headerHeight: CGFloat = 72
        
        static let sectionInsets = NSDirectionalEdgeInsets(top: 100, leading: 0, bottom: 48, trailing: 0)
    }

    private enum TopRankingLoop {
        static let multiplier = 50
        static let edgeBufferMultiplier = 2
    }
    
    private enum FilterFeedLayout {
        static let headerHeight: CGFloat = 30
        static let sectionInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 120, trailing: 20)
        static let listItemHeight: CGFloat = 110
        static let listInterGroupSpacing: CGFloat = 18
        static let blockColumnSpacing: CGFloat = 12
        static let blockItemSpacing: CGFloat = 12
        static let blockInterGroupSpacing: CGFloat = 16
        static let blockLargeHeightRatio: CGFloat = 1.35
        static let blockSmallHeightRatio: CGFloat = 0.95
    }
    
    private enum FilterFeedLayoutMode {
        case list
        case block
        
        var title: String {
            switch self {
            case .list:
                return "List Mode"
            case .block:
                return "Block Mode"
            }
        }
        
        mutating func toggle() {
            self = self == .list ? .block : .list
        }
    }
    
    struct TopRankingLoopItem: Hashable {
        let id: UUID
        let filter: FilterSummary
        let sourceIndex: Int
        let rank: Int
    }
    
    private let viewModel: CategoryRankingViewModel
    private let initialCategory: FilterCategory?
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let sortTypeSubject = PassthroughSubject<FilterSortType, Never>()
    private let categorySubject = PassthroughSubject<FilterCategory, Never>()
    private let loadMoreSubject = PassthroughSubject<Void, Never>()
    private let likeButtonTappedSubject = PassthroughSubject<(filterId: String, isLiked: Bool), Never>()
    private let filterDetailUpdatedSubject = PassthroughSubject<FilterDetailLikeUpdate, Never>()
    private let filterDeletedSubject = PassthroughSubject<String, Never>()
    private let filterUpdatedSubject = PassthroughSubject<FilterDetail, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // State
    private var currentSortType: FilterSortType = .popularity
    private var currentCategory: FilterCategory = .food
    
    private var topRankingFilters: [FilterSummary] = []
    private var topRankingLoopItems: [TopRankingLoopItem] = []
    private var feedFilters: [FilterSummary] = []
    private var filterFeedLayoutMode: FilterFeedLayoutMode = .list
    private var shouldScrollTopRankingToLoopCenter = false
    private var isAdjustingTopRankingLoop = false
    private var pendingCategorySelectionWorkItem: DispatchWorkItem?
    private var pendingCenteredIndex: Int?
    private weak var topRankingScrollView: UIScrollView?
    private var topRankingScrollOffsetObservation: NSKeyValueObservation?
    
    // MARK: - UI Components
    private lazy var mainCollectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.register(TopRankingCell.self, forCellWithReuseIdentifier: TopRankingCell.identifier)
        collectionView.register(CategoryFeedCell.self, forCellWithReuseIdentifier: CategoryFeedCell.identifier)
        collectionView.register(CategoryFeedBlockCell.self, forCellWithReuseIdentifier: CategoryFeedBlockCell.identifier)
        collectionView.register(
            TopRankingHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: TopRankingHeaderView.identifier
        )
        collectionView.register(
            CategoryFeedHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: CategoryFeedHeaderView.identifier
        )
        return collectionView
    }()
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    // MARK: - Initializer
    init(
        viewModel: CategoryRankingViewModel = DIContainer.shared.resolve(CategoryRankingViewModel.self),
        initialCategory: FilterCategory? = nil
    ) {
        self.viewModel = viewModel
        self.initialCategory = initialCategory
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "카테고리 랭킹"
        setupDataSource()
        bind()
        setupNotificationObservers()

        if let category = initialCategory {
            currentCategory = category
            categorySubject.send(category)
        }

        viewDidLoadSubject.send(())
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        findAndSetupTopRankingScrollView()
    }
    
    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(mainCollectionView)
    }
    
    override func configureLayout() {
        super.configureLayout()
        mainCollectionView.snp.makeConstraints { make in
            make.top.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }
    
    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFilterDidCreate(_:)),
            name: .filterDidCreate,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFilterDidUpdate(_:)),
            name: .filterDidUpdate,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFilterDidDelete(_:)),
            name: .filterDidDelete,
            object: nil
        )
    }

    /// 새 필터 생성 시 Feed 새로고침
    @objc private func handleFilterDidCreate(_ notification: Notification) {
        // 새 필터가 생성되면 목록을 새로고침하여 최신 데이터 반영
        viewDidLoadSubject.send(())
    }

    @objc private func handleFilterDidUpdate(_ notification: Notification) {
        guard let updatedFilter = notification.userInfo?["filter"] as? FilterDetail else {
            return
        }

        // ViewModel에 업데이트 전달 (ViewModel이 데이터 관리)
        filterUpdatedSubject.send(updatedFilter)
    }

    @objc private func handleFilterDidDelete(_ notification: Notification) {
        guard let deletedFilterId = notification.userInfo?["filterId"] as? String else {
            return
        }

        // ViewModel에 삭제 알림 (ViewModel이 데이터 관리)
        filterDeletedSubject.send(deletedFilterId)
    }

    // MARK: - Private Methods
    private func sortButtonTapped(_ sortType: FilterSortType) {
        currentSortType = sortType
        sortTypeSubject.send(sortType)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self else { return nil }
            if sectionIndex == 0 {
                // Section 0: Top Ranking
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(1.0)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(TopRankingLayout.itemWidthFraction),
                    heightDimension: .absolute(TopRankingLayout.groupHeight)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(TopRankingLayout.headerHeight)
                )
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
                section.contentInsets = TopRankingLayout.sectionInsets
                section.interGroupSpacing = TopRankingLayout.interGroupSpacing
                
                section.orthogonalScrollingBehavior = .groupPagingCentered
                
                section.visibleItemsInvalidationHandler = { items, offset, environment in
                    // 1. 컨테이너(화면) 너비
                    let containerWidth = environment.container.contentSize.width
                    guard containerWidth > 0 else { return }

                    // 2. 현재 가로 스크롤 상의 화면 중심 좌표 계산 (offset.x는 가로 스크롤 오프셋)
                    let visibleCenterX = offset.x + (containerWidth / 2.0)

                    // 3. 애니메이션이 적용될 유효 거리 (대략 아이템 너비만큼)
                    let activeDist = containerWidth * TopRankingLayout.itemWidthFraction

                    items.forEach { item in
                        // Cell에만 적용
                        guard item.representedElementCategory == .cell else { return }

                        // 4. 화면 중심과 아이템 중심 간의 거리
                        let distanceFromCenter = abs(item.frame.midX - visibleCenterX)

                        // 5. 거리 비율 계산 (0.0: 완전 중심, 1.0: 멀어짐)
                        // min(..., 1.0)을 통해 activeDist보다 멀면 1.0으로 고정
                        let ratio = min(distanceFromCenter / activeDist, 1.0)

                        // 6. Y축 이동 계산 (중심에 가까울수록 위로, 멀수록 원래 위치로)
                        // ratio 0 (중심) -> (1 - 0) * -90 = -90 (위로 이동)
                        // ratio 1 (외곽) -> (1 - 1) * -90 = 0   (원래 위치)
                        let yOffset = -TopRankingLayout.verticalOffset * (1 - ratio)

                        item.transform = CGAffineTransform(translationX: 0, y: yOffset)
                    }

                    let cellItems = items.filter { $0.representedElementCategory == .cell }
                    guard let centeredItem = cellItems.min(by: { lhs, rhs in
                        abs(lhs.frame.midX - visibleCenterX) < abs(rhs.frame.midX - visibleCenterX)
                    }) else { return }
                    self.adjustTopRankingLoopIfNeeded(centeredLoopIndex: centeredItem.indexPath.item)
                    self.scheduleCenteredCategoryUpdate(centeredLoopIndex: centeredItem.indexPath.item)
                }
                
                return section
                
            } else {
                return self.makeFilterFeedSection(environment: environment)
            }
        }
        
        return layout
    }
    
    private func makeFilterFeedSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(FilterFeedLayout.headerHeight)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        
        switch filterFeedLayoutMode {
        case .list:
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(FilterFeedLayout.listItemHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(FilterFeedLayout.listItemHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = FilterFeedLayout.listInterGroupSpacing
            section.contentInsets = FilterFeedLayout.sectionInsets
            section.boundarySupplementaryItems = [header]
            return section
            
        case .block:
            let availableWidth = environment.container.effectiveContentSize.width
            - FilterFeedLayout.sectionInsets.leading
            - FilterFeedLayout.sectionInsets.trailing
            let columnWidth = max((availableWidth - FilterFeedLayout.blockColumnSpacing) / 2, 0)
            let largeHeight = columnWidth * FilterFeedLayout.blockLargeHeightRatio
            let smallHeight = columnWidth * FilterFeedLayout.blockSmallHeightRatio
            let columnHeight = largeHeight + smallHeight + FilterFeedLayout.blockItemSpacing
            
            let largeItemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(largeHeight)
            )
            let smallItemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(smallHeight)
            )
            let largeItem = NSCollectionLayoutItem(layoutSize: largeItemSize)
            let smallItem = NSCollectionLayoutItem(layoutSize: smallItemSize)
            
            let columnSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.5),
                heightDimension: .absolute(columnHeight)
            )
            let leftColumn = NSCollectionLayoutGroup.vertical(
                layoutSize: columnSize,
                subitems: [largeItem, smallItem]
            )
            leftColumn.interItemSpacing = .fixed(FilterFeedLayout.blockItemSpacing)
            
            let rightColumn = NSCollectionLayoutGroup.vertical(
                layoutSize: columnSize,
                subitems: [smallItem, largeItem]
            )
            rightColumn.interItemSpacing = .fixed(FilterFeedLayout.blockItemSpacing)
            
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(columnHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: [leftColumn, rightColumn]
            )
            group.interItemSpacing = .fixed(FilterFeedLayout.blockColumnSpacing)
            
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = FilterFeedLayout.blockInterGroupSpacing
            section.contentInsets = FilterFeedLayout.sectionInsets
            section.boundarySupplementaryItems = [header]
            return section
        }
    }
    
    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: mainCollectionView
        ) { collectionView, indexPath, item in
            switch item {
            case .topRanking(let loopItem):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TopRankingCell.identifier,
                    for: indexPath
                ) as? TopRankingCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: loopItem.filter, rank: loopItem.rank)
                cell.onTap = { [weak self] in
                    self?.showFilterDetail(filterId: loopItem.filter.id)
                }
                return cell
                
            case .filterFeed(let filter):
                switch self.filterFeedLayoutMode {
                case .list:
                    guard let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: CategoryFeedCell.identifier,
                        for: indexPath
                    ) as? CategoryFeedCell else {
                        return UICollectionViewCell()
                    }
                    cell.configure(with: filter)
                    cell.onLikeTapped = { [weak self] filterId, isLiked in
                        self?.likeButtonTappedSubject.send((filterId, isLiked))
                    }
                    cell.onTap = { [weak self] filterId in
                        self?.showFilterDetail(filterId: filterId)
                    }
                    return cell
                    
                case .block:
                    guard let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: CategoryFeedBlockCell.identifier,
                        for: indexPath
                    ) as? CategoryFeedBlockCell else {
                        return UICollectionViewCell()
                    }
                    cell.configure(with: filter)
                    cell.onLikeTapped = { [weak self] filterId, isLiked in
                        self?.likeButtonTappedSubject.send((filterId, isLiked))
                    }
                    cell.onTap = { [weak self] filterId in
                        self?.showFilterDetail(filterId: filterId)
                    }
                    return cell
                }
                
            default:
                return UICollectionViewCell()
            }
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else { return nil }
            if indexPath.section == 0 {
                guard let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: TopRankingHeaderView.identifier,
                    for: indexPath
                ) as? TopRankingHeaderView else {
                    return nil
                }
                header.apply(sortType: self?.currentSortType ?? .popularity)
                header.onSortTypeSelected = { [weak self] sortType in
                    self?.sortButtonTapped(sortType)
                }
                return header
            }
            
            guard indexPath.section == 1 else { return nil }
            guard let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: CategoryFeedHeaderView.identifier,
                for: indexPath
            ) as? CategoryFeedHeaderView else {
                return nil
            }
            header.apply(modeTitle: self?.filterFeedLayoutMode.title ?? "List Mode")
            header.onLayoutModeTapped = { [weak self] in
                self?.toggleFilterFeedLayoutMode()
            }
            return header
        }
    }
    
    private func bind() {
        let input = CategoryRankingViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            sortTypeSelected: sortTypeSubject.eraseToAnyPublisher(),
            categorySelected: categorySubject.eraseToAnyPublisher(),
            loadMore: loadMoreSubject.eraseToAnyPublisher(),
            likeButtonTapped: likeButtonTappedSubject.eraseToAnyPublisher(),
            filterDetailUpdated: filterDetailUpdatedSubject.eraseToAnyPublisher(),
            filterDeleted: filterDeletedSubject.eraseToAnyPublisher(),
            filterUpdated: filterUpdatedSubject.eraseToAnyPublisher()
        )
        
        let output = viewModel.transform(input: input)
        
        output.topRankingFilters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filters in
                self?.updateTopRanking(with: filters)
            }
            .store(in: &cancellables)
        
        output.feedFilters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filters in
                self?.updateFeed(with: filters)
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
    }
    
    private func updateTopRanking(with filters: [FilterSummary]) {
        topRankingFilters = filters
        topRankingLoopItems = makeTopRankingLoopItems(from: filters)
        shouldScrollTopRankingToLoopCenter = filters.count > 1
        pendingCenteredIndex = nil
        pendingCategorySelectionWorkItem?.cancel()
        
        if !filters.contains(where: { $0.category == currentCategory }),
           let firstCategory = filters.first?.category {
            currentCategory = firstCategory
            categorySubject.send(firstCategory)
        }
        applySnapshot()
    }
    
    private func updateFeed(with filters: [FilterSummary]) {
        feedFilters = filters
        applySnapshot()
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.topRanking, .filterFeed])

        if !topRankingFilters.isEmpty {
            let items = topRankingLoopItems.map { Item.topRanking($0) }
            snapshot.appendItems(items, toSection: .topRanking)
        }

        if !feedFilters.isEmpty {
            let items = feedFilters.map { Item.filterFeed($0) }
            snapshot.appendItems(items, toSection: .filterFeed)
        }

        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            self?.findAndSetupTopRankingScrollView()
            self?.mainCollectionView.collectionViewLayout.invalidateLayout()
            self?.scrollTopRankingToLoopCenterIfNeeded()
        }
    }
    
    private func toggleFilterFeedLayoutMode() {
        filterFeedLayoutMode.toggle()
        topRankingScrollOffsetObservation = nil
        topRankingScrollView = nil
        mainCollectionView.setCollectionViewLayout(createLayout(), animated: true)
        mainCollectionView.reloadData()
        DispatchQueue.main.async { [weak self] in
            self?.findAndSetupTopRankingScrollView()
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func showFilterDetail(filterId: String) {
        coordinator?.showFilterDetail(filterId: filterId) { [weak self] filterId, isLiked, likeCount in
            self?.filterDetailUpdatedSubject.send(
                FilterDetailLikeUpdate(
                    filterId: filterId,
                    isLiked: isLiked,
                    likeCount: likeCount
                )
            )
        }
    }
    
    private func makeTopRankingLoopItems(from filters: [FilterSummary]) -> [TopRankingLoopItem] {
        guard !filters.isEmpty else { return [] }
        guard filters.count > 1 else {
            return [
                TopRankingLoopItem(
                    id: UUID(),
                    filter: filters[0],
                    sourceIndex: 0,
                    rank: 1
                )
            ]
        }

        let repeatedCount = TopRankingLoop.multiplier
        var items: [TopRankingLoopItem] = []
        items.reserveCapacity(filters.count * repeatedCount)
        for _ in 0..<repeatedCount {
            for (index, filter) in filters.enumerated() {
                items.append(
                    TopRankingLoopItem(
                        id: UUID(),
                        filter: filter,
                        sourceIndex: index,
                        rank: index + 1
                    )
                )
            }
        }
        return items
    }

    private func scheduleCenteredCategoryUpdate(centeredLoopIndex: Int) {
        guard !topRankingLoopItems.isEmpty else { return }
        guard centeredLoopIndex < topRankingLoopItems.count else { return }
        guard !isAdjustingTopRankingLoop else { return }
        let centeredIndex = topRankingLoopItems[centeredLoopIndex].sourceIndex
        guard centeredIndex != pendingCenteredIndex else { return }
        pendingCenteredIndex = centeredIndex

        pendingCategorySelectionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.applyCenteredCategoryIfNeeded(index: centeredIndex)
        }
        pendingCategorySelectionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func applyCenteredCategoryIfNeeded(index: Int) {
        guard index < topRankingFilters.count else { return }
        let category = topRankingFilters[index].category
        guard category != currentCategory else { return }
        currentCategory = category
        categorySubject.send(category)
    }

    private func scrollTopRankingToLoopCenterIfNeeded() {
        guard shouldScrollTopRankingToLoopCenter else { return }
        shouldScrollTopRankingToLoopCenter = false
        guard topRankingFilters.count > 1 else { return }
        let baseCount = topRankingFilters.count
        let middleStartIndex = (TopRankingLoop.multiplier / 2) * baseCount
        let currentIndex = topRankingFilters.firstIndex(where: { $0.category == currentCategory }) ?? 0
        let targetIndex = middleStartIndex + currentIndex
        guard targetIndex < topRankingLoopItems.count else { return }
        mainCollectionView.scrollToItem(
            at: IndexPath(item: targetIndex, section: 0),
            at: .centeredHorizontally,
            animated: false
        )
    }

    private func adjustTopRankingLoopIfNeeded(centeredLoopIndex: Int) {
        guard topRankingFilters.count > 1 else { return }
        guard !topRankingLoopItems.isEmpty else { return }
        guard !isAdjustingTopRankingLoop else { return }
        let baseCount = topRankingFilters.count
        let loopedCount = topRankingLoopItems.count
        let buffer = baseCount * TopRankingLoop.edgeBufferMultiplier
        let minimumIndex = buffer
        let maximumIndex = loopedCount - buffer - 1
        guard centeredLoopIndex < minimumIndex || centeredLoopIndex > maximumIndex else { return }

        let middleStartIndex = (TopRankingLoop.multiplier / 2) * baseCount
        let sourceIndex = topRankingLoopItems[centeredLoopIndex].sourceIndex
        let targetIndex = middleStartIndex + sourceIndex
        guard targetIndex < loopedCount else { return }

        isAdjustingTopRankingLoop = true
        mainCollectionView.scrollToItem(
            at: IndexPath(item: targetIndex, section: 0),
            at: .centeredHorizontally,
            animated: false
        )
        DispatchQueue.main.async { [weak self] in
            self?.isAdjustingTopRankingLoop = false
        }
    }

    private func findAndSetupTopRankingScrollView() {
        guard topRankingScrollView == nil else { return }

        func findScrollView(in view: UIView) -> UIScrollView? {
            for subview in view.subviews {
                if let scrollView = subview as? UIScrollView,
                   scrollView != mainCollectionView {
                    return scrollView
                }
                if let found = findScrollView(in: subview) {
                    return found
                }
            }
            return nil
        }

        if let scrollView = findScrollView(in: mainCollectionView) {
            topRankingScrollView = scrollView
            topRankingScrollOffsetObservation = scrollView.observe(
                \.contentOffset,
                options: [.new]
            ) { [weak self] _, _ in
                self?.mainCollectionView.collectionViewLayout.invalidateLayout()
            }
        }
    }
    
}

// MARK: - UICollectionViewDelegate
extension CategoryRankingViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .topRanking, .category:
            break
        case .filterFeed:
            break
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == mainCollectionView {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let frameHeight = scrollView.frame.height
            
            if contentHeight > frameHeight && offsetY > contentHeight - frameHeight - 200 {
                loadMoreSubject.send(())
            }
        }
    }
}
