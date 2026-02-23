//
//  ApplyFilterViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import UIKit
import SnapKit
import Combine

final class ApplyFilterViewController: BaseViewController {

    // MARK: - Properties

    private let viewModel: ApplyFilterViewModel
    private var cancellables = Set<AnyCancellable>()

    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let filterSelectedSubject = PassthroughSubject<FilterDetail, Never>()
    private let saveButtonTappedSubject = PassthroughSubject<Void, Never>()

    private var filters: [FilterDetail] = []
    private var originalImage: UIImage?
    private var isSaveInProgress = false
    var onFilterApplied: ((UIImage, FilterDetail?) -> Void)?

    // MARK: - Layout Constants

    private enum Layout {
        static let filterScrollHeight: CGFloat = 140
        static let filterItemSize: CGFloat = 80
        static let filterItemSpacing: CGFloat = 16
    }

    // MARK: - UI Components

    private let previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        return imageView
    }()

    private lazy var filterCollectionView: UICollectionView = {
        let layout = createCompositionalLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.decelerationRate = .fast
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(
            FilterPreviewCell.self,
            forCellWithReuseIdentifier: FilterPreviewCell.identifier
        )
        return collectionView
    }()

    private func createCompositionalLayout() -> UICollectionViewLayout {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .horizontal

        return UICollectionViewCompositionalLayout(
            sectionProvider: { _, layoutEnvironment in
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(Layout.filterItemSize),
                    heightDimension: .absolute(Layout.filterItemSize)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(Layout.filterItemSize),
                    heightDimension: .absolute(Layout.filterItemSize)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = Layout.filterItemSpacing

                let containerWidth = layoutEnvironment.container.effectiveContentSize.width
                let sideInset = max(0, (containerWidth - Layout.filterItemSize) / 2)
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 0,
                    leading: sideInset,
                    bottom: 0,
                    trailing: sideInset
                )
                return section
            },
            configuration: config
        )
    }

    // MARK: - Initialization

    init(viewModel: ApplyFilterViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        viewDidLoadSubject.send()
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(previewImageView)
        view.addSubview(filterCollectionView)
    }

    override func configureLayout() {
        super.configureLayout()

        previewImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(filterCollectionView.snp.top).offset(-20)
        }

        filterCollectionView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-100)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.filterScrollHeight)
        }
    }

    override func configureView() {
        super.configureView()
        title = "EDIT"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage.Icon.save,
            style: .plain,
            target: self,
            action: #selector(saveButtonTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .Feelter.gray75
    }

    // MARK: - Binding

    private func bindViewModel() {
        let input = ApplyFilterViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            filterSelected: filterSelectedSubject.eraseToAnyPublisher(),
            saveButtonTapped: saveButtonTappedSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.filters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filters in
                print("🎨 [ApplyFilterVC] 필터 목록 수신: \(filters.count)개")
                self?.filters = filters
                self?.filterCollectionView.reloadData()

                // 레이아웃 완료 후 첫 번째 필터 선택 및 스크롤
                DispatchQueue.main.async {
                    if let firstFilter = filters.first {
                        print("🎨 [ApplyFilterVC] 첫 번째 필터 자동 선택: \(firstFilter.title)")

                        self?.filterCollectionView.layoutIfNeeded()

                        // 첫 번째 아이템(Original)을 중앙에 배치
                        self?.filterCollectionView.scrollToItem(
                            at: IndexPath(item: 0, section: 0),
                            at: .centeredHorizontally,
                            animated: false
                        )

                        self?.updateCellScales(animated: false)
                        self?.filterSelectedSubject.send(firstFilter)
                    }
                }
            }
            .store(in: &cancellables)

        output.currentFilteredImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                self?.previewImageView.image = image
                // 첫 이미지를 원본으로 저장
                if self?.originalImage == nil {
                    self?.originalImage = image
                    self?.filterCollectionView.reloadData()
                }
            }
            .store(in: &cancellables)

        output.saveCompleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.isSaveInProgress = false
                self?.onFilterApplied?(result.image, result.appliedFilter)
                self?.navigationController?.popViewController(animated: true)
            }
            .store(in: &cancellables)

        output.exportQueued
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.isSaveInProgress = true
                self.navigationItem.rightBarButtonItem?.isEnabled = false
                GlobalToastPresenter.shared.show(message: "필터 적용중", duration: 3)
                self.navigationController?.popViewController(animated: true)
            }
            .store(in: &cancellables)

        output.error
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.isSaveInProgress = false
                self?.navigationItem.rightBarButtonItem?.isEnabled = true
                self?.showAlert(message: error)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func saveButtonTapped() {
        guard !isSaveInProgress else { return }
        isSaveInProgress = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        saveButtonTappedSubject.send()
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension ApplyFilterViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filters.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FilterPreviewCell.identifier,
            for: indexPath
        ) as? FilterPreviewCell else {
            return UICollectionViewCell()
        }

        let filter = filters[indexPath.item]
        cell.configure(with: filter, originalImage: originalImage)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension ApplyFilterViewController: UICollectionViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCellScales()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        snapToNearestCell()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            snapToNearestCell()
        }
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let cellWidthIncludingSpacing = Layout.filterItemSize + Layout.filterItemSpacing
        let rawIndex = targetContentOffset.pointee.x / cellWidthIncludingSpacing
        let index = round(rawIndex)

        let maxOffset = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        let snappedOffset = index * cellWidthIncludingSpacing
        targetContentOffset.pointee.x = min(max(0, snappedOffset), maxOffset)
    }

    private func snapToNearestCell() {
        let centerPoint = CGPoint(
            x: filterCollectionView.contentOffset.x + filterCollectionView.bounds.width / 2,
            y: filterCollectionView.bounds.height / 2
        )

        if let indexPath = filterCollectionView.indexPathForItem(at: centerPoint) {
            let selectedIndex = indexPath.item
            print("🎨 [ApplyFilterVC] 스크롤 끝 - 선택된 인덱스: \(selectedIndex)")

            if selectedIndex >= 0 && selectedIndex < filters.count {
                let selectedFilter = filters[selectedIndex]
                print("🎨 [ApplyFilterVC] 필터 선택 이벤트 전송: \(selectedFilter.title)")
                filterSelectedSubject.send(selectedFilter)
            } else {
                print("❌ [ApplyFilterVC] 잘못된 인덱스: \(selectedIndex), 필터 개수: \(filters.count)")
            }
        }
    }

    private func updateCellScales(animated: Bool = true) {
        let centerX = filterCollectionView.contentOffset.x + filterCollectionView.bounds.width / 2

        for cell in filterCollectionView.visibleCells {
            guard let indexPath = filterCollectionView.indexPath(for: cell) else { continue }
            guard let attributes = filterCollectionView.layoutAttributesForItem(at: indexPath) else { continue }

            let cellCenterX = attributes.center.x
            let distance = abs(centerX - cellCenterX)
            let maxDistance = Layout.filterItemSize + Layout.filterItemSpacing
            let scale = max(0.8, 1 - (distance / maxDistance) * 0.2)

            if animated {
                UIView.animate(withDuration: 0.2) {
                    cell.transform = CGAffineTransform(scaleX: scale, y: scale)
                }
            } else {
                cell.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }
    }
}

// MARK: - FilterPreviewCell

private final class FilterPreviewCell: UICollectionViewCell {

    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .Feelter.gray90
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.caption1
        label.textColor = .Feelter.gray0
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(titleLabel)

        thumbnailImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.width.height.equalTo(80)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(thumbnailImageView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
        }
    }

    func configure(with filter: FilterDetail, originalImage: UIImage?) {
        titleLabel.text = filter.title

        // 원본 필터인 경우 (previewImages가 비어있는 경우)
        if filter.previewImages.isEmpty {
            if let original = originalImage {
                thumbnailImageView.contentMode = .scaleAspectFill
                // 다운샘플링 적용
                thumbnailImageView.image = resize(image: original, to: CGSize(width: 80, height: 80))
            } else {
                thumbnailImageView.image = UIImage(systemName: "photo.fill")
                thumbnailImageView.tintColor = .Feelter.gray60
                thumbnailImageView.contentMode = .center
            }
        } else if let thumbnailURL = filter.previewImages.first {
            thumbnailImageView.contentMode = .scaleAspectFill
            thumbnailImageView.setFeelterImage(with: thumbnailURL)
        } else {
            thumbnailImageView.image = UIImage(systemName: "photo")
            thumbnailImageView.tintColor = .Feelter.gray60
            thumbnailImageView.contentMode = .center
        }
    }

    private func resize(image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
