//
//  ImageViewerViewController.swift
//  Feelter
//
//  Created by Claude Code on 1/17/26.
//

import UIKit
import SnapKit

/// 이미지 갤러리 뷰어
/// - 전체 화면으로 이미지 표시
/// - 좌우 스와이프로 이미지 전환
/// - Pinch-to-zoom 지원
final class ImageViewerViewController: UIViewController {

    // MARK: - Properties

    private let images: [ChatImageSource]
    private let initialIndex: Int
    private var currentIndex: Int

    private let pageViewController: UIPageViewController
    private let pageControl = UIPageControl()
    private let closeButton = UIButton(type: .system)
    private let counterLabel = UILabel()

    // MARK: - Initialization

    init(images: [ChatImageSource], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        self.currentIndex = initialIndex

        self.pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        configureView()
        configureHierarchy()
        configureLayout()
        configurePageViewController()
        updatePageInfo()
    }

    // MARK: - Configuration

    private func configureView() {
        view.backgroundColor = .black
    }

    private func configureHierarchy() {
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)

        view.addSubview(closeButton)
        view.addSubview(counterLabel)
    }

    private func configureLayout() {
        pageViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.trailing.equalToSuperview().inset(16)
            make.width.height.equalTo(44)
        }

        counterLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.centerX.equalToSuperview()
        }
    }

    private func configurePageViewController() {
        pageViewController.dataSource = self
        pageViewController.delegate = self

        // 닫기 버튼 설정
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 22
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        // 카운터 라벨 설정
        counterLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        counterLabel.textColor = .white
        counterLabel.textAlignment = .center

        // 초기 페이지 설정
        if let firstVC = makePageViewController(at: initialIndex) {
            pageViewController.setViewControllers(
                [firstVC],
                direction: .forward,
                animated: false
            )
        } else {
        }
    }

    private func updatePageInfo() {
        counterLabel.text = "\(currentIndex + 1) / \(images.count)"
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }

    // MARK: - Helper Methods

    private func makePageViewController(at index: Int) -> ImagePageViewController? {
        guard index >= 0 && index < images.count else {
            return nil
        }

        let pageVC = ImagePageViewController(imageSource: images[index], index: index)
        pageVC.onTapped = { [weak self] in
            self?.dismiss(animated: true)
        }
        return pageVC
    }
}

// MARK: - UIPageViewControllerDataSource

extension ImageViewerViewController: UIPageViewControllerDataSource {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let currentVC = viewController as? ImagePageViewController else {
            return nil
        }

        let index = currentVC.index - 1
        return makePageViewController(at: index)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let currentVC = viewController as? ImagePageViewController else {
            return nil
        }

        let index = currentVC.index + 1
        return makePageViewController(at: index)
    }
}

// MARK: - UIPageViewControllerDelegate

extension ImageViewerViewController: UIPageViewControllerDelegate {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let currentVC = pageViewController.viewControllers?.first as? ImagePageViewController else {
            return
        }

        currentIndex = currentVC.index
        updatePageInfo()
    }
}

// MARK: - Single Image Page ViewController

/// 단일 이미지를 표시하는 페이지 뷰 컨트롤러
/// - Pinch-to-zoom 지원
/// - 탭하면 부모 뷰어 닫기
final class ImagePageViewController: UIViewController {

    // MARK: - Properties

    let imageSource: ChatImageSource
    let index: Int
    var onTapped: (() -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    // MARK: - Initialization

    init(imageSource: ChatImageSource, index: Int) {
        self.imageSource = imageSource
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        configureView()
        configureHierarchy()
        configureLayout()
        loadImage()
    }

    // MARK: - Configuration

    private func configureView() {
        view.backgroundColor = .clear

        // ScrollView 설정 (zoom 지원)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        // ImageView 설정
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        // 로딩 인디케이터
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true

        // 탭 제스처
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        tapGesture.cancelsTouchesInView = true
        imageView.addGestureRecognizer(tapGesture)
    }

    private func configureHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        view.addSubview(loadingIndicator)
    }

    private func configureLayout() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(scrollView)
            make.height.equalTo(scrollView)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func loadImage() {
        switch imageSource {
        case .local(let image):
            imageView.image = image
            updateImageViewConstraints(for: image.size)

        case .remote(let path):
            loadingIndicator.startAnimating()
            imageView.setFeelterImage(with: path) { [weak self] success in
                DispatchQueue.main.async {
                    self?.loadingIndicator.stopAnimating()
                    if success, let image = self?.imageView.image {
                        self?.updateImageViewConstraints(for: image.size)
                    } else {
                    }
                }
            }
        }
    }

    private func updateImageViewConstraints(for imageSize: CGSize) {
        // 이미지 비율에 맞게 constraint 조정
        guard imageSize.width > 0 && imageSize.height > 0 else { return }

        let aspectRatio = imageSize.width / imageSize.height

        imageView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
            make.height.equalTo(scrollView.snp.width).dividedBy(aspectRatio)
        }
    }

    // MARK: - Actions

    @objc private func imageTapped() {
        onTapped?()
    }
}

// MARK: - UIScrollViewDelegate

extension ImagePageViewController: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 줌 후 이미지를 중앙에 배치
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
    }
}
