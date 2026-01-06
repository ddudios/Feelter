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
    }

    enum Item: Hashable {
        case hero(Filter)
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
        collectionView.register(TodayFilterCell.self, forCellWithReuseIdentifier: TodayFilterCell.identifier)
        return collectionView
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

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

    // MARK: - Private Methods
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            
            // Section 0: 화면 높이의 60%
            let screenHeight = environment.container.contentSize.height
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
                self?.updateUI(with: filter)
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

    private func updateUI(with filter: Filter) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.todayFilter])
        snapshot.appendItems([.hero(filter)], toSection: .todayFilter)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
