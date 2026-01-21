//
//  ChatImageGridView.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import UIKit
import SnapKit
import AVFoundation

final class ChatImageGridView: UIView {

    // MARK: - Callback

    /// 이미지 탭 시 실행되는 클로저 (탭한 이미지의 인덱스 전달)
    var onImageTapped: ((Int) -> Void)?

    private enum Layout {
        static let spacing: CGFloat = 2
        /// 최대 너비 = 최대 높이 (1:1 비율 제한, 화면 너비의 약 60%)
        static let maxSize: CGFloat = min(UIScreen.main.bounds.width * 0.6, 250)
    }

    private var imageViews: [UIView] = []
    private var heightConstraint: Constraint?
    private var widthConstraint: Constraint?
    private var maxHeightConstraint: Constraint?
    private var rootStackView: UIStackView?
    private var currentImages: [ChatImageSource] = []

    // 전체 이미지 버블용 로딩 인디케이터 (하나만)
    private let centralLoadingIndicator = UIActivityIndicatorView(style: .medium)

    // ✅ 고유 ID로 이전 configure 호출 무시
    private var currentConfigureId = UUID()

    // ✅ 로딩 중인 이미지 개수 (음수 방지)
    private var loadingImageCount = 0 {
        didSet {
            // 음수 방지
            if loadingImageCount < 0 {
                loadingImageCount = 0
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupInitialConstraints()
        setupCentralLoadingIndicator()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInitialConstraints()
        setupCentralLoadingIndicator()
    }

    private func setupInitialConstraints() {
        // 초기에는 높이/너비 0으로 설정 (이미지 없는 상태)
        backgroundColor = .clear
        // 초기 intrinsicContentSize 설정
        currentHeight = 0
        currentWidth = 0
        invalidateIntrinsicContentSize()
    }

    private func setupCentralLoadingIndicator() {
        centralLoadingIndicator.color = .systemGray
        centralLoadingIndicator.hidesWhenStopped = true
        addSubview(centralLoadingIndicator)

        centralLoadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    /// 이미지 로딩 완료 시 호출될 콜백
    var onImageLoadingCompleted: (() -> Void)?

    /// 현재 설정된 높이를 저장하여 intrinsicContentSize에 사용
    private var currentHeight: CGFloat = 0
    private var currentWidth: CGFloat = 0

    /// intrinsicContentSize를 통해 초기 크기 제공 (레이아웃 겹침 방지)
    override var intrinsicContentSize: CGSize {
        return CGSize(width: currentWidth, height: currentHeight)
    }

    /// ✅ 완전 초기화 메서드 (prepareForReuse에서 호출)
    func reset() {

        // 고유 ID 갱신 (이전 콜백 무시)
        currentConfigureId = UUID()

        // 로딩 카운트 초기화
        loadingImageCount = 0
        centralLoadingIndicator.stopAnimating()

        // 현재 이미지 초기화
        currentImages = []

        // 기존 뷰 제거
        imageViews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        rootStackView?.removeFromSuperview()
        rootStackView = nil

        // 크기 초기화
        currentHeight = 0
        currentWidth = 0
        invalidateIntrinsicContentSize()

        // 제약조건 초기화
        snp.removeConstraints()
        heightConstraint = nil
        widthConstraint = nil
        maxHeightConstraint = nil
    }

    func configure(with images: [ChatImageSource]) {

        // ✅ 새로운 configure ID 생성 (이전 콜백 무효화)
        let configureId = UUID()
        currentConfigureId = configureId

        // 현재 이미지 저장
        currentImages = images

        // 기존 뷰 제거
        imageViews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        rootStackView?.removeFromSuperview()
        rootStackView = nil

        // 로딩 카운트 초기화
        loadingImageCount = 0
        centralLoadingIndicator.stopAnimating()

        // 이미지가 없으면 높이 0으로 설정
        if images.isEmpty {
            currentHeight = 0
            currentWidth = 0
            invalidateIntrinsicContentSize()
            snp.remakeConstraints { make in
                heightConstraint = make.height.equalTo(0).priority(.high).constraint
                widthConstraint = make.width.equalTo(0).priority(.high).constraint
            }
            return
        }

        let limitedImages = Array(images.prefix(5))

        // 원격 이미지 개수 카운트
        let remoteImageCount = limitedImages.filter {
            if case .remote = $0 { return true }
            return false
        }.count

        // 원격 이미지가 있으면 중앙 로딩 인디케이터 시작
        if remoteImageCount > 0 {
            loadingImageCount = remoteImageCount
            centralLoadingIndicator.startAnimating()
        }

        // 이미지뷰 생성
        for (index, source) in limitedImages.enumerated() {
            let containerView = UIView()
            containerView.backgroundColor = .clear  // 투명 배경
            containerView.clipsToBounds = true
            containerView.isUserInteractionEnabled = true
            containerView.tag = index  // 인덱스 저장

            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = .clear
            containerView.addSubview(imageView)

            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            // 이미지 로딩
            switch source {
            case .local(let image):
                imageView.image = image
            case .remote(let path):
                imageView.setFeelterImage(with: path) { [weak self] success in
                    guard let self = self else { return }

                    // ✅ 이 콜백이 최신 configure 호출에서 온 것인지 확인
                    guard configureId == self.currentConfigureId else {
                        return
                    }


                    DispatchQueue.main.async {
                        self.loadingImageCount -= 1

                        // 모든 이미지 로딩 완료
                        if self.loadingImageCount <= 0 {
                            self.centralLoadingIndicator.stopAnimating()
                            self.onImageLoadingCompleted?()
                        }
                    }
                }
            case .video(let thumbnailImage, let videoURL, let isLocal):
                if let thumbnail = thumbnailImage {
                    imageView.image = thumbnail
                    addPlayIcon(to: containerView)
                } else {
                    // 썸네일이 없으면 비동기로 생성
                    imageView.image = UIImage(systemName: "video.fill")
                    imageView.contentMode = .scaleAspectFit
                    imageView.tintColor = .Feelter.gray60

                    // 비동기로 썸네일 생성
                    loadVideoThumbnail(videoURL: videoURL, isLocal: isLocal, configureId: configureId) { [weak self, weak containerView] thumbnail in
                        guard let self = self, let containerView = containerView else { return }
                        guard configureId == self.currentConfigureId else { return }

                        DispatchQueue.main.async {
                            if let thumb = thumbnail {
                                imageView.image = thumb
                                imageView.contentMode = .scaleAspectFill
                                self.addPlayIcon(to: containerView)
                            }
                        }
                    }

                    // 재생 아이콘은 일단 추가
                    addPlayIcon(to: containerView)
                }
            }

            // 탭 제스처 추가
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
            tapGesture.cancelsTouchesInView = true
            containerView.addGestureRecognizer(tapGesture)

            imageViews.append(containerView)
        }

        // 이미지 개수에 따른 높이 설정
        let imageCount = imageViews.count
        let targetHeight: CGFloat

        switch imageCount {
        case 2:
            targetHeight = Layout.maxSize / 2
        case 5:
            // 위 3개: maxSize/3 높이, 아래 2개: maxSize/3 높이 → 총 2/3 높이
            targetHeight = Layout.maxSize * 2 / 3
        default:
            targetHeight = Layout.maxSize
        }


        // intrinsicContentSize 업데이트 (레이아웃 겹침 방지)
        currentHeight = targetHeight
        currentWidth = Layout.maxSize
        invalidateIntrinsicContentSize()

        snp.remakeConstraints { make in
            heightConstraint = make.height.equalTo(targetHeight).priority(.required).constraint
            widthConstraint = make.width.equalTo(Layout.maxSize).priority(.required).constraint
            maxHeightConstraint = make.height.lessThanOrEqualTo(Layout.maxSize).constraint
        }

        layoutImages(for: imageViews.count)

        // 레이아웃 강제 업데이트
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func layoutImages(for count: Int) {
        switch count {
        case 1:
            layoutSingleImage()
        case 2:
            let rowStack = makeHorizontalStack(views: [imageViews[0], imageViews[1]])
            attach(stackView: rowStack)
        case 3:
            let rightColumn = makeVerticalStack(views: [imageViews[1], imageViews[2]])
            let rowStack = makeHorizontalStack(views: [imageViews[0], rightColumn])
            attach(stackView: rowStack)
        case 4:
            let topRow = makeHorizontalStack(views: [imageViews[0], imageViews[1]])
            let bottomRow = makeHorizontalStack(views: [imageViews[2], imageViews[3]])
            let columnStack = makeVerticalStack(views: [topRow, bottomRow])
            attach(stackView: columnStack)
        case 5:
            let topRow = makeHorizontalStack(views: [imageViews[0], imageViews[1], imageViews[2]])
            let bottomRow = makeHorizontalStack(views: [imageViews[3], imageViews[4]])
            let columnStack = makeVerticalStack(views: [topRow, bottomRow])
            attach(stackView: columnStack)
        default:
            layoutSingleImage()
        }
    }

    private func layoutSingleImage() {
        guard let imageView = imageViews.first else { return }
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func attach(stackView: UIStackView) {
        rootStackView = stackView
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func makeHorizontalStack(views: [UIView]) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: views)
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = Layout.spacing
        return stackView
    }

    private func makeVerticalStack(views: [UIView]) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: views)
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = Layout.spacing
        return stackView
    }

    // MARK: - Actions

    @objc private func imageTapped(_ gesture: UITapGestureRecognizer) {
        guard let containerView = gesture.view else {
            return
        }

        let index = containerView.tag
        onImageTapped?(index)
    }

    private func addPlayIcon(to containerView: UIView) {
        // 기존 재생 아이콘 제거 (중복 방지)
        containerView.subviews.forEach { view in
            if let iconView = view as? UIImageView, iconView.image == UIImage(systemName: "play.circle.fill") {
                view.removeFromSuperview()
            }
        }

        let playIconView = UIImageView(image: UIImage(systemName: "play.circle.fill"))
        playIconView.tintColor = .white
        playIconView.contentMode = .scaleAspectFit
        containerView.addSubview(playIconView)
        playIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(44)
        }
    }

    private func loadVideoThumbnail(videoURL: String, isLocal: Bool, configureId: UUID, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url: URL?

            if isLocal {
                url = URL(fileURLWithPath: videoURL)
            } else {
                // 원격 URL 생성
                let baseURLString = Config.baseURL.absoluteString
                let cleanedBase = baseURLString.hasSuffix("/") ? String(baseURLString.dropLast()) : baseURLString

                var path = videoURL
                if path.hasPrefix("/") && !path.hasPrefix("/v1/") {
                    path = "/v1" + path
                } else if !path.hasPrefix("/") {
                    path = "/v1/" + path
                }

                url = URL(string: cleanedBase + path)
            }

            guard let videoUrl = url else {
                completion(nil)
                return
            }

            // AVAsset으로 썸네일 생성
            let asset = AVAsset(url: videoUrl)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0, preferredTimescale: 600)

            if let imageRef = try? generator.copyCGImage(at: time, actualTime: nil) {
                let thumbnail = UIImage(cgImage: imageRef)
                completion(thumbnail)
            } else {
                completion(nil)
            }
        }
    }
}
