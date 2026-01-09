//
//  FilterDetailViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import UIKit
import Combine
import SnapKit

final class FilterDetailViewController: BaseViewController {
    private enum Layout {
        static let customTabBarHeight: CGFloat = 72
        static let customTabBarBottomSpacing: CGFloat = 10
        static let bottomContentPadding: CGFloat = 12
    }

    private enum Section: Int, CaseIterable {
        case preview
        case background
        case presets
        case purchase
        case creator
    }

    private enum Item: Hashable {
        case preview(String)
        case background(String)
        case presets(String)
        case purchase(String)
        case creator(String)
    }

    private let filterId: String
    private let viewModel: FilterDetailViewModel
    
    private let viewDidLoadSubject = PassthroughSubject<String, Never>()
    private let likeButtonTappedSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var currentIsLiked = false
    private var currentLikeCount: Int?
    private var currentFilterDetail: FilterDetail?
    var onLikeStateChanged: ((String, Bool, Int) -> Void)?

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.register(
            FilterPreviewCompareCell.self,
            forCellWithReuseIdentifier: FilterPreviewCompareCell.identifier
        )
        collectionView.register(
            FilterMetadataCell.self,
            forCellWithReuseIdentifier: FilterMetadataCell.identifier
        )
        collectionView.register(
            FilterPresetsCell.self,
            forCellWithReuseIdentifier: FilterPresetsCell.identifier
        )
        collectionView.register(
            FilterPurchaseButtonCell.self,
            forCellWithReuseIdentifier: FilterPurchaseButtonCell.identifier
        )
        collectionView.register(
            FilterCreatorInfoCell.self,
            forCellWithReuseIdentifier: FilterCreatorInfoCell.identifier
        )
        return collectionView
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    private lazy var likeBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(
            image: UIImage.Icon.likeEmpty,
            style: .plain,
            target: self,
            action: #selector(likeButtonTapped)
        )
    }()
    
    init(
        filterId: String,
        viewModel: FilterDetailViewModel = FilterDetailViewModel(
            filterUsecase: DIContainer.shared.resolve(FilterUsecaseProtocol.self)
        )
    ) {
        self.filterId = filterId
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDataSource()
        bind()
        viewDidLoadSubject.send(filterId)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBottomInsetIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent, let currentLikeCount {
            onLikeStateChanged?(filterId, currentIsLiked, currentLikeCount)
        }
    }
    
    override func configureView() {
        super.configureView()
        navigationItem.rightBarButtonItem = likeBarButtonItem
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(collectionView)
    }

    override func configureLayout() {
        super.configureLayout()

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.horizontalEdges.bottom.equalToSuperview()
        }
    }
    
    private func bind() {
        let input = FilterDetailViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            likeButtonTapped: likeButtonTappedSubject.eraseToAnyPublisher()
        )
        
        let output = viewModel.transform(input: input)
        
        output.filterDetail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filter in
                self?.title = filter.title
                self?.currentIsLiked = filter.isLiked
                self?.currentLikeCount = filter.likeCount
                self?.currentFilterDetail = filter
                self?.reconfigurePreviewSection()
                self?.reconfigureMetadataSection()
                self?.reconfigurePresetsSection()
                self?.reconfigurePurchaseSection()
                self?.reconfigureCreatorSection()
            }
            .store(in: &cancellables)
        
        output.isLiked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLiked in
                self?.updateLikeButton(isLiked: isLiked)
                self?.currentIsLiked = isLiked
            }
            .store(in: &cancellables)
        
        output.likeCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] likeCount in
                self?.currentLikeCount = likeCount
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
    
    private func updateLikeButton(isLiked: Bool) {
        let image = isLiked ? UIImage.Icon.likeFill : UIImage.Icon.likeEmpty
        likeBarButtonItem.image = image
    }
    
    @objc private func likeButtonTapped() {
        likeButtonTappedSubject.send(())
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            guard let sectionType = Section(rawValue: sectionIndex) else { return nil }
            let estimatedHeight: CGFloat
            let topInset: CGFloat
            let bottomInset: CGFloat

            switch sectionType {
            case .preview:
                estimatedHeight = 560
                topInset = 16
                bottomInset = 0
            case .background:
                estimatedHeight = 140
                topInset = 0
                bottomInset = 16
            case .presets:
                estimatedHeight = 200
                topInset = 0
                bottomInset = 16
            case .purchase:
                estimatedHeight = 64
                topInset = 0
                bottomInset = 16
            case .creator:
                estimatedHeight = 260
                topInset = 0
                bottomInset = 16
            }

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(estimatedHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(estimatedHeight)
            )
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: topInset, leading: 0, bottom: bottomInset, trailing: 0)
            return section
        }
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            switch item {
            case .preview:
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: FilterPreviewCompareCell.identifier,
                    for: indexPath
                ) as? FilterPreviewCompareCell else {
                    return UICollectionViewCell()
                }
                if let filterDetail = self?.currentFilterDetail {
                    cell.configure(
                        previewImages: filterDetail.previewImages,
                        price: filterDetail.price,
                        likeCount: filterDetail.likeCount,
                        buyerCount: filterDetail.buyerCount
                    )
                } else {
                    cell.configure(previewImages: [], price: 0, likeCount: 0, buyerCount: 0)
                }
                return cell
            case .background:
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: FilterMetadataCell.identifier,
                    for: indexPath
                ) as? FilterMetadataCell else {
                    return UICollectionViewCell()
                }
                if let filterDetail = self?.currentFilterDetail {
                    cell.configure(metadata: filterDetail.metadata)
                } else {
                    cell.configure(metadata: .empty)
                }
                return cell
            case .presets:
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: FilterPresetsCell.identifier,
                    for: indexPath
                ) as? FilterPresetsCell else {
                    return UICollectionViewCell()
                }
                if let filterDetail = self?.currentFilterDetail {
                    cell.configure(
                        values: filterDetail.filterValues,
                        isLocked: !filterDetail.isDownloaded
                    )
                } else {
                    cell.configure(values: nil, isLocked: true)
                }
                return cell
            case .purchase:
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: FilterPurchaseButtonCell.identifier,
                    for: indexPath
                ) as? FilterPurchaseButtonCell else {
                    return UICollectionViewCell()
                }
                let isPurchased = self?.currentFilterDetail?.isDownloaded ?? false
                cell.configure(isPurchased: isPurchased)
                return cell
            case .creator:
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: FilterCreatorInfoCell.identifier,
                    for: indexPath
                ) as? FilterCreatorInfoCell else {
                    return UICollectionViewCell()
                }
                if let filterDetail = self?.currentFilterDetail {
                    cell.configure(creator: filterDetail.creator, description: filterDetail.description)
                }
                return cell
            }
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.preview, .background, .presets, .purchase, .creator])
        snapshot.appendItems([.preview(filterId)], toSection: .preview)
        snapshot.appendItems([.background(filterId)], toSection: .background)
        snapshot.appendItems([.presets(filterId)], toSection: .presets)
        snapshot.appendItems([.purchase(filterId)], toSection: .purchase)
        snapshot.appendItems([.creator(filterId)], toSection: .creator)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigurePreviewSection() {
        var snapshot = dataSource.snapshot()
        let previewItem = Item.preview(filterId)
        if snapshot.indexOfItem(previewItem) == nil {
            snapshot.appendItems([previewItem], toSection: .preview)
        } else {
            snapshot.reloadItems([previewItem])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigureMetadataSection() {
        var snapshot = dataSource.snapshot()
        let metadataItem = Item.background(filterId)
        if snapshot.indexOfItem(metadataItem) == nil {
            snapshot.appendItems([metadataItem], toSection: .background)
        } else {
            snapshot.reloadItems([metadataItem])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigurePresetsSection() {
        var snapshot = dataSource.snapshot()
        let presetsItem = Item.presets(filterId)
        if snapshot.indexOfItem(presetsItem) == nil {
            snapshot.appendItems([presetsItem], toSection: .presets)
        } else {
            snapshot.reloadItems([presetsItem])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigurePurchaseSection() {
        var snapshot = dataSource.snapshot()
        let purchaseItem = Item.purchase(filterId)
        if snapshot.indexOfItem(purchaseItem) == nil {
            snapshot.appendItems([purchaseItem], toSection: .purchase)
        } else {
            snapshot.reloadItems([purchaseItem])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigureCreatorSection() {
        var snapshot = dataSource.snapshot()
        let creatorItem = Item.creator(filterId)
        if snapshot.indexOfItem(creatorItem) == nil {
            snapshot.appendItems([creatorItem], toSection: .creator)
        } else {
            snapshot.reloadItems([creatorItem])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func updateBottomInsetIfNeeded() {
        let bottomInset = view.safeAreaInsets.bottom
        + Layout.customTabBarHeight
        + Layout.customTabBarBottomSpacing
        + Layout.bottomContentPadding

        if collectionView.contentInset.bottom != bottomInset {
            collectionView.contentInset.bottom = bottomInset
            collectionView.scrollIndicatorInsets.bottom = bottomInset
        }
    }
}
