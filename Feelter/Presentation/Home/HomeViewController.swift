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

    // MARK: - Types
    enum Section {
        case todayFilter
        case banner
    }

    enum Item: Hashable {
        case hero(Filter)
        case banner(Banner)
    }

    private let viewModel: HomeViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePageIndicatorPosition()
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
    }

    // MARK: - Private Methods
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in

            if sectionIndex == 0 {
                // Section 0: TodayFilter - 화면 높이의 60%
                let screenHeight = environment.container.effectiveContentSize.height
                let heroHeight = screenHeight * 0.6

                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(heroHeight)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(heroHeight)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                let section = NSCollectionLayoutSection(group: group)
                return section

            } else {
                // Section 1: Banner - 가로 스크롤
                let screenHeight = environment.container.effectiveContentSize.height
                let bannerHeight = screenHeight * 0.13

                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(bannerHeight)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.9),
                    heightDimension: .absolute(bannerHeight)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPaging
                section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
                section.interGroupSpacing = 20

                // 가로 스크롤 시 페이지 업데이트
                section.visibleItemsInvalidationHandler = { [weak self] visibleItems, scrollOffset, environment in
                    guard let self = self, self.totalBannerCount > 0 else { return }

                    // 스크롤 오프셋으로 현재 페이지 계산
                    let containerWidth = environment.container.contentSize.width
                    let groupWidth = containerWidth * 0.9 // fractionalWidth(0.9)
                    let spacing: CGFloat = 20
                    let pageWidth = groupWidth + spacing

                    // 현재 페이지 번호 (1부터 시작)
                    let currentPage = max(1, min(Int(round(scrollOffset.x / pageWidth)) + 1, self.totalBannerCount))

                    DispatchQueue.main.async {
                        self.pageIndicatorLabel.text = "\(currentPage) / \(self.totalBannerCount)"
                    }
                }

                return section
            }
        }
        return layout
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            switch item {
            case .hero(let filter):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TodayFilterCell.identifier,
                    for: indexPath
                ) as? TodayFilterCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: filter)
                return cell

            case .banner(let banner):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: BannerCell.identifier,
                    for: indexPath
                ) as? BannerCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: banner.imageURL)
                return cell
            }
        }
    }

    private func bind() {
        let input = HomeViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher()
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

        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { isLoading in
                // TODO: 로딩 인디케이터 처리
                print("Loading: \(isLoading)")
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

    private func updateTodayFilter(with filter: Filter) {
        var snapshot = dataSource.snapshot()

        // Section 0이 없으면 추가
        if !snapshot.sectionIdentifiers.contains(.todayFilter) {
            snapshot.appendSections([.todayFilter])
        }

        // 기존 아이템 삭제 후 새로 추가
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .todayFilter))
        snapshot.appendItems([.hero(filter)], toSection: .todayFilter)

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func updateBanners(with banners: [Banner]) {
        var snapshot = dataSource.snapshot()

        // Section 1이 없으면 추가
        if !snapshot.sectionIdentifiers.contains(.banner) {
            snapshot.appendSections([.banner])
        }

        // 기존 아이템 삭제 후 새로 추가
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .banner))
        let bannerItems = banners.map { Item.banner($0) }
        snapshot.appendItems(bannerItems, toSection: .banner)

        totalBannerCount = banners.count
        pageIndicatorLabel.isHidden = banners.isEmpty
        pageIndicatorLabel.text = "1 / \(totalBannerCount)"

        dataSource.apply(snapshot, animatingDifferences: false)

        // 페이지 인디케이터 위치 업데이트
        DispatchQueue.main.async {
            self.updatePageIndicatorPosition()
        }
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
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

        // 완전한 캡슐형으로 만들기 위해 cornerRadius를 높이의 절반으로 설정
        pageIndicatorLabel.layoutIfNeeded()
        pageIndicatorLabel.layer.cornerRadius = pageIndicatorLabel.bounds.height / 2
    }
}

// MARK: - UICollectionViewDelegate
extension HomeViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 세로 스크롤 시 페이지 인디케이터도 함께 이동
        updatePageIndicatorPosition()
    }
}
