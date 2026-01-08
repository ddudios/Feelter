//
//  FeedViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit
import Combine
import SnapKit

final class FeedViewController: BaseViewController {

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
        static let itemWidthFraction: CGFloat = 0.56
        static let groupHeight: CGFloat = 440
        static let interGroupSpacing: CGFloat = 12
        static let verticalOffset: CGFloat = 24
        static let headerHeight: CGFloat = 72
        static let sectionInsets = NSDirectionalEdgeInsets(top: 40, leading: 0, bottom: 48, trailing: 0)
    }
    
    private enum TopRankingLoop {
        static let multiplier = 50
        static let edgeBufferMultiplier = 2
    }
    
    struct TopRankingLoopItem: Hashable {
        let id: UUID
        let filter: FilterSummary
        let sourceIndex: Int
        let rank: Int
    }

    private let viewModel: FeedViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let sortTypeSubject = PassthroughSubject<FilterSortType, Never>()
    private let categorySubject = PassthroughSubject<FilterCategory, Never>()
    private let loadMoreSubject = PassthroughSubject<Void, Never>()
    private let likeButtonTappedSubject = PassthroughSubject<(filterId: String, isLiked: Bool), Never>()
    private var cancellables = Set<AnyCancellable>()

    // State
    private var currentSortType: FilterSortType = .popularity
    private var currentCategory: FilterCategory = .food
    private var topRankingFilters: [FilterSummary] = []
    private var topRankingLoopItems: [TopRankingLoopItem] = []
    private var feedFilters: [FilterSummary] = []
    private var pendingCategorySelectionWorkItem: DispatchWorkItem?
    private var pendingCenteredIndex: Int?
    private var pendingLoopRecenteringWorkItem: DispatchWorkItem?
    private var shouldScrollTopRankingToLoopCenter = false
    private var isAdjustingTopRankingLoop = false

    // MARK: - UI Components
    private lazy var mainCollectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.register(CategoryRankingCell.self, forCellWithReuseIdentifier: CategoryRankingCell.identifier)
        collectionView.register(FilterFeedCell.self, forCellWithReuseIdentifier: FilterFeedCell.identifier)
        collectionView.register(
            TopRankingHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: TopRankingHeaderView.identifier
        )
        return collectionView
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    // MARK: - Initializer
    init(viewModel: FeedViewModel = DIContainer.shared.resolve(FeedViewModel.self)) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "FEED"
        setupDataSource()
        bind()
        viewDidLoadSubject.send(())
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

    // MARK: - Private Methods
    private func sortButtonTapped(_ sortType: FilterSortType) {
        currentSortType = sortType
        sortTypeSubject.send(sortType)
    }

    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
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
                section.visibleItemsInvalidationHandler = { [weak self] items, offset, environment in
                    let containerWidth = environment.container.contentSize.width
                    guard containerWidth > 0 else { return }
                    
                    let centerX = offset.x + containerWidth / 2
                    
                    // 1. 애니메이션이 일어날 전체 구간 (아이템 하나의 너비 정도가 적당)
                    let itemWidth = containerWidth * TopRankingLayout.itemWidthFraction
                    let animationRange = itemWidth
                    
                    let cellItems = items.filter { $0.representedElementCategory == .cell }
                    
                    cellItems.forEach { item in
                        // 2. 중앙에서 얼마나 떨어져 있는지 계산
                        let distanceFromCenter = abs(item.frame.midX - centerX)
                        
                        // 3. 거리 비율 계산 (0.0 = 완전 중앙, 1.0 = 멀리 떨어짐)
                        // animationRange보다 멀어지면 최대값(1.0)으로 고정
                        let ratio = min(distanceFromCenter / animationRange, 1.0)
                        
                        // 4. Y축 오프셋 계산 (비율에 따라 선형적으로 변환)
                        // ratio가 0(중앙)이면 offset 0 (원래 위치 = 위쪽)
                        // ratio가 1(사이드)이면 offset 24 (아래로 내려감)
                        let yOffset = TopRankingLayout.verticalOffset * ratio
                        
                        // 5. 적용
                        item.transform = CGAffineTransform(translationX: 0, y: yOffset)
                        
                        // (선택사항) 중앙에 가까울수록 살짝 커지게 하려면 아래 코드 주석 해제
                        // let scale = 1.0 + (0.1 * (1.0 - ratio)) // 중앙 1.1배, 사이드 1.0배
                        // item.transform = item.transform.scaledBy(x: scale, y: scale)
                    }
                    
                    // 중앙 아이템 인덱스 업데이트 로직 (기존 유지)
                    self?.scheduleCenteredCategoryUpdate(
                        with: items,
                        offset: offset,
                        environment: environment
                    )
                }

                return section

            } else {
                // Section 1: Filter Feed
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(100)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(100)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 12
                section.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 20, bottom: 100, trailing: 20)

                return section
            }
        }

        return layout
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: mainCollectionView
        ) { collectionView, indexPath, item in
            switch item {
            case .topRanking(let loopItem):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: CategoryRankingCell.identifier,
                    for: indexPath
                ) as? CategoryRankingCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: loopItem.filter, rank: loopItem.rank)
                return cell

            case .filterFeed(let filter):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: FilterFeedCell.identifier,
                    for: indexPath
                ) as? FilterFeedCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: filter)
                cell.onLikeTapped = { [weak self] filterId, isLiked in
                    self?.likeButtonTappedSubject.send((filterId, isLiked))
                }
                return cell

            default:
                return UICollectionViewCell()
            }
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else { return nil }
            guard indexPath.section == 0 else { return nil }
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
    }

    private func bind() {
        let input = FeedViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            sortTypeSelected: sortTypeSubject.eraseToAnyPublisher(),
            categorySelected: categorySubject.eraseToAnyPublisher(),
            loadMore: loadMoreSubject.eraseToAnyPublisher(),
            likeButtonTapped: likeButtonTappedSubject.eraseToAnyPublisher()
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
        pendingLoopRecenteringWorkItem?.cancel()
        pendingLoopRecenteringWorkItem = nil
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
            self?.scrollTopRankingToLoopCenterIfNeeded()
        }
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func scheduleCenteredCategoryUpdate(
        with items: [NSCollectionLayoutVisibleItem],
        offset: CGPoint,
        environment: NSCollectionLayoutEnvironment
    ) {
        guard let centeredLoopIndex = centeredLoopIndex(
            from: items,
            offset: offset,
            environment: environment
        ) else {
            return
        }
        adjustTopRankingLoopIfNeeded(centeredLoopIndex: centeredLoopIndex)
        guard !isAdjustingTopRankingLoop else { return }
        let centeredIndex = topRankingLoopItems[centeredLoopIndex].sourceIndex
        guard centeredIndex != pendingCenteredIndex else { return }
        pendingCenteredIndex = centeredIndex

        pendingCategorySelectionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.applyCenteredCategoryIfNeeded(index: centeredIndex)
        }
        pendingCategorySelectionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func centeredLoopIndex(
        from items: [NSCollectionLayoutVisibleItem],
        offset: CGPoint,
        environment: NSCollectionLayoutEnvironment
    ) -> Int? {
        guard !topRankingLoopItems.isEmpty else { return nil }
        let containerWidth = environment.container.contentSize.width
        guard containerWidth > 0 else { return nil }
        let centerX = offset.x + containerWidth / 2

        let cellItems = items.filter { $0.representedElementCategory == .cell }
        guard let closestItem = cellItems.min(by: { lhs, rhs in
            abs(lhs.frame.midX - centerX) < abs(rhs.frame.midX - centerX)
        }) else {
            return nil
        }

        let itemWidth = containerWidth * TopRankingLayout.itemWidthFraction
        let centerThreshold = itemWidth * 0.08
        if abs(closestItem.frame.midX - centerX) > centerThreshold {
            return nil
        }

        let index = closestItem.indexPath.item
        guard index < topRankingLoopItems.count else { return nil }
        return index
    }

    private func applyCenteredCategoryIfNeeded(index: Int) {
        let category = topRankingFilters[index].category
        guard category != currentCategory else { return }
        currentCategory = category
        categorySubject.send(category)
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
                let item = TopRankingLoopItem(
                    id: UUID(),
                    filter: filter,
                    sourceIndex: index,
                    rank: index + 1
                )
                items.append(item)
            }
        }
        return items
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
        let indexPath = IndexPath(item: targetIndex, section: 0)
        mainCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
    }
    
    private func adjustTopRankingLoopIfNeeded(centeredLoopIndex: Int) {
        guard topRankingFilters.count > 1 else { return }
        guard !topRankingLoopItems.isEmpty else { return }
        guard !isAdjustingTopRankingLoop else { return }
        pendingLoopRecenteringWorkItem?.cancel()
        pendingLoopRecenteringWorkItem = nil
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
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isAdjustingTopRankingLoop = true
            self.mainCollectionView.scrollToItem(
                at: IndexPath(item: targetIndex, section: 0),
                at: .centeredHorizontally,
                animated: false
            )
            DispatchQueue.main.async { [weak self] in
                self?.isAdjustingTopRankingLoop = false
            }
        }
        pendingLoopRecenteringWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }
}

// MARK: - UICollectionViewDelegate
extension FeedViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 무한 스크롤: 하단 근처에서 추가 로드
        if scrollView == mainCollectionView {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let frameHeight = scrollView.frame.height

            // contentHeight가 유효하고, 스크롤이 하단 200pt 근처에 있을 때만 로드
            if contentHeight > frameHeight && offsetY > contentHeight - frameHeight - 200 {
                loadMoreSubject.send(())
            }
        }
    }
}
