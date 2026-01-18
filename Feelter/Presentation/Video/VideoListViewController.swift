//
//  VideoViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import UIKit
import SnapKit
import Combine

final class VideoListViewController: BaseViewController {

    weak var coordinator: FeedCoordinator?

    private enum Layout {
        static let cellEstimatedHeight: CGFloat = 300
        static let sectionSpacing: CGFloat = 20
        static let sectionInset: CGFloat = 16
        static let headerEstimatedHeight: CGFloat = 64
    }

    private enum Section {
        case main
    }

    private let viewModel: VideoViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let loadMoreVideosSubject = PassthroughSubject<Void, Never>()
    private let likeButtonTappedSubject = PassthroughSubject<(videoId: String, isLiked: Bool), Never>()
    private var cancellables = Set<AnyCancellable>()
    private var safeAreaTopInset: CGFloat = 0

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .Feelter.gray100
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.register(VideoListCell.self, forCellWithReuseIdentifier: VideoListCell.identifier)
        collectionView.register(
            VideoListHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: VideoListHeaderView.identifier
        )
        return collectionView
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Section, VideoSummary>!

    init(viewModel: VideoViewModel = DIContainer.shared.resolve(VideoViewModel.self)) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDataSource()
        setupCollectionView()
        bind()
        viewDidLoadSubject.send(())
    }

    private func setupCollectionView() {
        collectionView.delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let topInset = view.safeAreaInsets.top
        if safeAreaTopInset != topInset {
            safeAreaTopInset = topInset
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.reloadData()
        }
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(collectionView)
    }

    override func configureLayout() {
        super.configureLayout()
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(Layout.cellEstimatedHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 0,
            bottom: 0,
            trailing: 0
        )

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(Layout.cellEstimatedHeight)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Layout.sectionSpacing
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 0,
            bottom: 120,
            trailing: 0
        )

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(Layout.headerEstimatedHeight)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        header.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 0,
            bottom: Layout.sectionSpacing,
            trailing: 0
        )
        section.boundarySupplementaryItems = [header]

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, VideoSummary>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, video in
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: VideoListCell.identifier,
                for: indexPath
            ) as? VideoListCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: video)
            cell.onLikeTapped = { [weak self] videoId, isLiked in
                self?.likeButtonTappedSubject.send((videoId: videoId, isLiked: isLiked))
            }
            return cell
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else {
                return nil
            }
            guard let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: VideoListHeaderView.identifier,
                for: indexPath
            ) as? VideoListHeaderView else {
                return nil
            }
            header.configure(
                title: "Feelter",
                safeAreaTopInset: self.safeAreaTopInset
            )
            return header
        }
    }

    private func bind() {
        let input = VideoViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            loadMoreVideos: loadMoreVideosSubject.eraseToAnyPublisher(),
            likeButtonTapped: likeButtonTappedSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.videos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videos in
                self?.applySnapshot(videos: videos)
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

    private func applySnapshot(videos: [VideoSummary]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, VideoSummary>()
        snapshot.appendSections([.main])
        snapshot.appendItems(videos, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(
            title: "오류",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDelegate
extension VideoListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let video = dataSource.itemIdentifier(for: indexPath) else { return }
        coordinator?.showVideoDetail(videoId: video.id, videoSummary: video)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height

        let triggerPoint = contentHeight - height - 200

        if offsetY > triggerPoint && contentHeight > 0 {
            loadMoreVideosSubject.send(())
        }
    }
}
