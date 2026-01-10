//
//  FilterDetailViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import UIKit
import Combine
import SnapKit
import WebKit
import iamport_ios

final class FilterDetailViewController: BaseViewController {
    
    // MARK: - Constants & Enums
    
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

    // MARK: - Properties
    
    private let filterId: String
    private let viewModel: FilterDetailViewModel

    private lazy var paymentViewModel: PaymentViewModel = {
        PaymentViewModel(
            usecase: DIContainer.shared.resolve(PaymentUsecaseProtocol.self),
            filterId: filterId,
            price: currentFilterDetail?.price ?? 0
        )
    }()

    private let viewDidLoadSubject = PassthroughSubject<String, Never>()
    private let likeButtonTappedSubject = PassthroughSubject<Void, Never>()
    private let purchaseButtonTappedSubject = PassthroughSubject<Void, Never>()
    private let iamportResponseSubject = PassthroughSubject<(success: Bool, impUid: String?, errorMsg: String?), Never>()

    private var cancellables = Set<AnyCancellable>()
    private var currentIsLiked = false
    private var currentLikeCount: Int?
    private var currentFilterDetail: FilterDetail?
    private var isPaymentViewModelBound = false
    var onLikeStateChanged: ((String, Bool, Int) -> Void)?

    // MARK: - UI Components
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        
        collectionView.register(FilterPreviewCompareCell.self, forCellWithReuseIdentifier: FilterPreviewCompareCell.identifier)
        collectionView.register(FilterMetadataCell.self, forCellWithReuseIdentifier: FilterMetadataCell.identifier)
        collectionView.register(FilterPresetsCell.self, forCellWithReuseIdentifier: FilterPresetsCell.identifier)
        collectionView.register(FilterPurchaseButtonCell.self, forCellWithReuseIdentifier: FilterPurchaseButtonCell.identifier)
        collectionView.register(FilterCreatorInfoCell.self, forCellWithReuseIdentifier: FilterCreatorInfoCell.identifier)
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
    
    // MARK: - Initializer
    
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
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDataSource()
        bindFilterDetailViewModel()
        viewDidLoadSubject.send(filterId)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParent, let currentLikeCount {
            onLikeStateChanged?(filterId, currentIsLiked, currentLikeCount)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBottomInsetIfNeeded()
    }
    
    // MARK: - Setup UI
    
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
    
    // MARK: - Bind ViewModel
    
    private func bindFilterDetailViewModel() {
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

                self?.bindPaymentViewModelIfNeeded()
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

    private func bindPaymentViewModelIfNeeded() {
        guard !isPaymentViewModelBound else { return }
        isPaymentViewModelBound = true

        let input = PaymentViewModel.Input(
            didTapPurchaseButton: purchaseButtonTappedSubject.eraseToAnyPublisher(),
            iamportResponseReceived: iamportResponseSubject.eraseToAnyPublisher()
        )

        let output = paymentViewModel.transform(input: input)

        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.showLoadingIndicator()
                } else {
                    self?.hideLoadingIndicator()
                }
            }
            .store(in: &cancellables)

        output.showError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showAlert(message: message)
            }
            .store(in: &cancellables)

        output.requestIamportPayment
            .receive(on: DispatchQueue.main)
            .sink { [weak self] orderInfo in
                self?.launchIamportPayment(orderInfo: orderInfo)
            }
            .store(in: &cancellables)

        output.paymentDidFinish
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handlePaymentSuccess(result: result)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Action Methods
    
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
    
    // MARK: - CollectionView Layout & DataSource
    
    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            guard let sectionType = Section(rawValue: sectionIndex) else { return nil }
            let estimatedHeight: CGFloat
            let topInset: CGFloat
            let bottomInset: CGFloat

            switch sectionType {
            case .preview:
                estimatedHeight = 560
                topInset = 0
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

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(estimatedHeight))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(estimatedHeight))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: topInset, leading: 0, bottom: bottomInset, trailing: 0)
            return section
        }
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            switch item {
            case .preview:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FilterPreviewCompareCell.identifier, for: indexPath) as? FilterPreviewCompareCell else { return UICollectionViewCell() }
                if let filterDetail = self?.currentFilterDetail {
                    cell.configure(
                        previewImages: filterDetail.previewImages,
                        price: filterDetail.price,
                        likeCount: filterDetail.likeCount,
                        buyerCount: filterDetail.buyerCount
                    )
                }
                return cell
            case .background:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FilterMetadataCell.identifier, for: indexPath) as? FilterMetadataCell else { return UICollectionViewCell() }
                if let filterDetail = self?.currentFilterDetail {
                    cell.configure(metadata: filterDetail.metadata)
                }
                return cell
            case .presets:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FilterPresetsCell.identifier, for: indexPath) as? FilterPresetsCell else { return UICollectionViewCell() }
                if let filterDetail = self?.currentFilterDetail {
                    cell.configure(values: filterDetail.filterValues, isLocked: !filterDetail.isDownloaded)
                } else {
                    cell.configure(values: nil, isLocked: true)
                }
                return cell
            case .purchase:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FilterPurchaseButtonCell.identifier, for: indexPath) as? FilterPurchaseButtonCell else { return UICollectionViewCell() }
                let isPurchased = self?.currentFilterDetail?.isDownloaded ?? false
                cell.configure(isPurchased: isPurchased)
                cell.onPurchaseButtonTapped = { [weak self] in
                    self?.purchaseButtonTappedSubject.send(())
                }
                return cell
            case .creator:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FilterCreatorInfoCell.identifier, for: indexPath) as? FilterCreatorInfoCell else { return UICollectionViewCell() }
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
        let item = Item.preview(filterId)
        if snapshot.indexOfItem(item) == nil {
            snapshot.appendItems([item], toSection: .preview)
        } else {
            snapshot.reloadItems([item])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigureMetadataSection() {
        var snapshot = dataSource.snapshot()
        let item = Item.background(filterId)
        if snapshot.indexOfItem(item) == nil {
            snapshot.appendItems([item], toSection: .background)
        } else {
            snapshot.reloadItems([item])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigurePresetsSection() {
        var snapshot = dataSource.snapshot()
        let item = Item.presets(filterId)
        if snapshot.indexOfItem(item) == nil {
            snapshot.appendItems([item], toSection: .presets)
        } else {
            snapshot.reloadItems([item])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigurePurchaseSection() {
        var snapshot = dataSource.snapshot()
        let item = Item.purchase(filterId)
        if snapshot.indexOfItem(item) == nil {
            snapshot.appendItems([item], toSection: .purchase)
        } else {
            snapshot.reloadItems([item])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigureCreatorSection() {
        var snapshot = dataSource.snapshot()
        let item = Item.creator(filterId)
        if snapshot.indexOfItem(item) == nil {
            snapshot.appendItems([item], toSection: .creator)
        } else {
            snapshot.reloadItems([item])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func updateBottomInsetIfNeeded() {
        let bottomInset = view.safeAreaInsets.bottom + Layout.customTabBarHeight + Layout.customTabBarBottomSpacing + Layout.bottomContentPadding
        if collectionView.contentInset.bottom != bottomInset {
            collectionView.contentInset.bottom = bottomInset
            collectionView.scrollIndicatorInsets.bottom = bottomInset
        }
    }

    // MARK: - Payment Handling (KG Inicis + WebView)

    private func launchIamportPayment(orderInfo: OrderInfo) {
        // ✅ 내 가맹점 식별코드 (INIpayTest 설정 완료된 상태)
        let userCode = "imp10391932"

        var payment = IamportPayment(
            pg: PG.html5_inicis.makePgRawName(pgId: "INIpayTest"),
            merchant_uid: orderInfo.orderCode,
            amount: "\(orderInfo.totalPrice)"
        )
        
        payment.pay_method = PayMethod.card.rawValue
        payment.name = currentFilterDetail?.title ?? "필터 구매"
        payment.buyer_name = "홍길동"
        payment.buyer_email = "test@feelter.com"
        payment.app_scheme = "feelter"

        print("📱 KG이니시스 결제 요청 (UserCode: \(userCode))")
        print("주문번호: \(orderInfo.orderCode)")
        print("금액: \(orderInfo.totalPrice)원")

        // 1. WebView 매번 새로 생성
        let paymentWebView = WKWebView()
        paymentWebView.backgroundColor = .white

        // 2. ViewController 생성 및 설정
        let webViewController = UIViewController()
        webViewController.view = paymentWebView
        webViewController.title = "결제"
        
        // ✨ [Full Screen] 결제창을 풀스크린으로 띄움
        webViewController.modalPresentationStyle = .fullScreen
        self.present(webViewController, animated: true)

        // 3. 아임포트 결제 실행
        Iamport.shared.paymentWebView(
            webViewMode: paymentWebView,
            userCode: userCode,
            payment: payment
        ) { [weak self, weak webViewController] response in
            guard let self = self else { return }

            // ✨ [Full Screen] 닫기 (dismiss)
            webViewController?.dismiss(animated: true)

            print("📱 아임포트 결제 응답: success=\(response?.success ?? false)")
            print("Message: \(response?.error_msg ?? "No Error Message")")

            if let success = response?.success, success {
                self.iamportResponseSubject.send((true, response?.imp_uid, nil))
            } else {
                self.iamportResponseSubject.send((false, nil, response?.error_msg ?? "결제가 취소되었습니다."))
            }
        }
    }

    private func handlePaymentSuccess(result: PaymentValidationResult) {
        let alert = UIAlertController(
            title: "결제 완료",
            message: "필터 구매가 완료되었습니다!\n이제 필터를 다운로드하여 사용할 수 있습니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.viewDidLoadSubject.send(self.filterId)
        })
        present(alert, animated: true)
    }

    private func showLoadingIndicator() {
        view.isUserInteractionEnabled = false
    }

    private func hideLoadingIndicator() {
        view.isUserInteractionEnabled = true
    }
}
