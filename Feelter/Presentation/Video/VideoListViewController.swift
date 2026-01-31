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

    private enum Section: Int, CaseIterable {
        case featured = 0
        case main = 1
    }

    private enum FeaturedMock {
        static let id = "featured-video-mock"
        static let thumbnailAssetName = "videoThumbnail"
        static let title = "색감·명암 기본 공식"
        static let description = """
        사진 보정이 어렵게 느껴지시나요?
        이 영상에서는 초보자도 바로 적용할 수 있는 사진 보정의 기본 공식과 색감 정리 방법을 알려드립니다.

        ✔ 노출과 대비 조절 순서
        ✔ 색온도와 채도 균형 잡는 법
        ✔ 자연스러운 보정이 되는 기준

        과하지 않게, 오래 봐도 질리지 않는
        사진 보정 노하우를 공유합니다.
        """
        static let viewCount = 128
        static let likeCount = 21
        static let duration: Double = 108
        static var createdAt: Date {
            Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        }
    }

    private let viewModel: VideoViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let loadMoreVideosSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    private lazy var featuredMockVideo: VideoSummary = {
        VideoSummary(
            id: FeaturedMock.id,
            fileName: "featured_mock",
            title: FeaturedMock.title,
            description: FeaturedMock.description,
            duration: FeaturedMock.duration,
            thumbnailURL: "asset:\(FeaturedMock.thumbnailAssetName)",
            availableQualities: [],
            viewCount: FeaturedMock.viewCount,
            likeCount: FeaturedMock.likeCount,
            isLiked: false,
            createdAt: FeaturedMock.createdAt
        )
    }()

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .Feelter.gray100
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.register(VideoListCell.self, forCellWithReuseIdentifier: VideoListCell.identifier)
        collectionView.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderView.identifier
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
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            guard let section = Section(rawValue: sectionIndex) else {
                fatalError("Unknown section")
            }

            switch section {
            case .featured:
                // 첫 번째 동영상: 화면 높이의 60% (safeArea 무시)
                let screenHeight = UIScreen.main.bounds.height
                let featuredHeight = screenHeight * 0.6

                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(featuredHeight)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(featuredHeight)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                let section = NSCollectionLayoutSection(group: group)
                return section

            case .main:
                // 나머지 동영상들: 기존 레이아웃 유지
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(Layout.cellEstimatedHeight)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

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

            let isFeatured = indexPath.section == Section.featured.rawValue
            cell.configure(with: video, isFeatured: isFeatured)
            return cell
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

            // Section 1 (main)에만 헤더 표시
            if indexPath.section == Section.main.rawValue {
                header?.configure(with: "오늘의 보정팁")
            }

            return header
        }
    }

    private func bind() {
        let input = VideoViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            loadMoreVideos: loadMoreVideosSubject.eraseToAnyPublisher(),
            likeButtonTapped: Empty().eraseToAnyPublisher()
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

        snapshot.appendSections([.featured])
        snapshot.appendItems([featuredMockVideo], toSection: .featured)

        let reorderedVideos = reorderedMainVideos(from: videos)
        if !reorderedVideos.isEmpty {
            snapshot.appendSections([.main])
            snapshot.appendItems(reorderedVideos, toSection: .main)
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reorderedMainVideos(from videos: [VideoSummary]) -> [VideoSummary] {
        guard let firstVideo = videos.first else { return [] }
        guard videos.count > 1 else { return videos }
        return Array(videos.dropFirst()) + [firstVideo]
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
        if video.id == FeaturedMock.id {
            return
        }
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
