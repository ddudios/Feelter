//
//  FilterPreviewCompareCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/9/26.
//

import UIKit
import SnapKit

final class FilterPreviewCompareCell: BaseCollectionViewCell, UIGestureRecognizerDelegate {
    private let initialSliderValue: Float = 0.5
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private let imageContainerView = UIView()
    private let compareImageView = FilterImageCompareView()

    private let compareIconContainerView = UIView()
    private let compareIconImageView = UIImageView()
    private let compareGestureView = UIView()

    private let afterLabel = CapsuleLabel(
        padding: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
    )
    private let beforeLabel = CapsuleLabel(
        padding: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
    )

    private let compareSlider = UISlider()
    private let sliderLineView = UIView()
    private var compareControlLeadingConstraint: Constraint?

    private let priceLabel = UILabel()
    private let coinLabel = UILabel()

    private let downloadCardView = UIView()
    private let downloadTitleLabel = UILabel()
    private let downloadCountLabel = UILabel()

    private let likeCardView = UIView()
    private let likeTitleLabel = UILabel()
    private let likeCountLabel = UILabel()
    private let statsContainerView = UIView()

    private lazy var downloadContentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [downloadTitleLabel, downloadCountLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        return stackView
    }()

    private lazy var likeContentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [likeTitleLabel, likeCountLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        return stackView
    }()

    private lazy var compareControlView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [afterLabel, compareIconContainerView, beforeLabel])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 6
        stackView.isUserInteractionEnabled = false
        return stackView
    }()

    private lazy var comparePanGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleComparePan(_:)))
        gesture.delegate = self
        return gesture
    }()

    private lazy var compareTapGesture: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(handleCompareTap(_:)))
    }()

    private lazy var imagePanGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleImagePan(_:)))
        gesture.delegate = self
        return gesture
    }()

    private lazy var imageTapGesture: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(handleImageTap(_:)))
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        compareSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureHierarchy() {
        contentView.addSubview(imageContainerView)
        imageContainerView.addSubview(compareImageView)
        contentView.addSubview(compareSlider)
        contentView.addSubview(compareGestureView)
        compareGestureView.addSubview(compareControlView)
        contentView.addSubview(sliderLineView)
        contentView.addSubview(priceLabel)
        contentView.addSubview(coinLabel)
        contentView.addSubview(statsContainerView)
        compareIconContainerView.addSubview(compareIconImageView)
        statsContainerView.addSubview(downloadCardView)
        statsContainerView.addSubview(likeCardView)
        downloadCardView.addSubview(downloadContentStackView)
        likeCardView.addSubview(likeContentStackView)
    }

    override func configureLayout() {
        imageContainerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(imageContainerView.snp.width)
        }

        compareImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        compareSlider.snp.makeConstraints { make in
            make.top.equalTo(imageContainerView.snp.bottom).offset(8)
            make.leading.trailing.equalTo(imageContainerView)
            make.height.equalTo(32)
        }

        compareGestureView.snp.makeConstraints { make in
            make.centerY.equalTo(compareSlider)
            make.leading.trailing.equalTo(compareSlider)
            make.height.equalTo(44)
        }

        compareControlView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            compareControlLeadingConstraint = make.leading.equalTo(compareGestureView.snp.leading).constraint
        }

        sliderLineView.snp.makeConstraints { make in
            make.top.equalTo(compareSlider.snp.bottom).offset(20)
            make.leading.trailing.equalTo(imageContainerView)
            make.height.equalTo(1)
        }
        
        priceLabel.snp.makeConstraints { make in
            make.leading.equalTo(sliderLineView)
            make.top.equalTo(sliderLineView.snp.bottom).offset(16)
        }
        
        coinLabel.snp.makeConstraints { make in
            make.leading.equalTo(priceLabel.snp.trailing).offset(8)
            make.bottom.equalTo(priceLabel.snp.bottom)
        }

        statsContainerView.snp.makeConstraints { make in
            make.top.equalTo(priceLabel.snp.bottom).offset(12)
            make.centerX.equalTo(imageContainerView)
            make.width.equalTo(212)
            make.height.equalTo(70)
            make.bottom.equalToSuperview().inset(8)
        }

        downloadCardView.snp.makeConstraints { make in
            make.leading.equalTo(sliderLineView.snp.leading)
            make.top.equalToSuperview()
            make.width.equalTo(110)
            make.height.equalTo(62)
        }
        
        likeCardView.snp.makeConstraints { make in
            make.leading.equalTo(downloadCardView.snp.trailing).offset(12)
            make.top.equalToSuperview()
            make.width.equalTo(110)
            make.height.equalTo(63)
        }

        downloadContentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }

        likeContentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }

        compareIconContainerView.snp.makeConstraints { make in
            make.width.height.equalTo(30)
        }

        compareIconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }

    override func configureView() {
        super.configureView()

        imageContainerView.backgroundColor = .Feelter.gray90
        imageContainerView.layer.cornerRadius = 24
        imageContainerView.layer.cornerCurve = .continuous
        imageContainerView.clipsToBounds = true

        afterLabel.text = "After"
        afterLabel.font = TextStyle.Pretendard.caption1
        afterLabel.textColor = .Feelter.gray60
        afterLabel.backgroundColor = UIColor.Feelter.gray90?.withAlphaComponent(0.7)

        beforeLabel.text = "Before"
        beforeLabel.font = TextStyle.Pretendard.caption1
        beforeLabel.textColor = .Feelter.gray60
        beforeLabel.backgroundColor = UIColor.Feelter.gray90?.withAlphaComponent(0.7)

        compareIconContainerView.backgroundColor = UIColor.Feelter.gray90 ?? .darkGray
        compareIconContainerView.layer.cornerRadius = 15
        compareIconContainerView.layer.borderWidth = 1
        compareIconContainerView.layer.borderColor = UIColor.Feelter.gray75?.withAlphaComponent(0.6).cgColor

        compareIconImageView.contentMode = .scaleAspectFit
        compareIconImageView.tintColor = UIColor.Feelter.gray15 ?? .white
        compareIconImageView.image = UIImage.FilterProps.sharpness?.withRenderingMode(.alwaysTemplate)

        compareSlider.minimumTrackTintColor = .clear
        compareSlider.maximumTrackTintColor = .clear
        compareSlider.isContinuous = true
        compareSlider.value = initialSliderValue
        compareSlider.isUserInteractionEnabled = false

        let thumbImage = makeTransparentThumbImage()
        compareSlider.setThumbImage(thumbImage, for: .normal)
        compareSlider.setThumbImage(thumbImage, for: .highlighted)

        sliderLineView.backgroundColor = .Feelter.deepTurquoise

        priceLabel.font = TextStyle.Mulgyeol.title1
        priceLabel.textColor = .Feelter.gray0

        coinLabel.font = TextStyle.Mulgyeol.body1
        coinLabel.textColor = .Feelter.gray75
        coinLabel.text = "Coin"

        downloadTitleLabel.font = TextStyle.Pretendard.semibold1
        downloadTitleLabel.textColor = .Feelter.gray75
        downloadTitleLabel.text = "다운로드"

        downloadCountLabel.font = TextStyle.Pretendard.title1
        downloadCountLabel.textColor = .Feelter.gray30

        likeTitleLabel.font = TextStyle.Pretendard.semibold1
        likeTitleLabel.textColor = .Feelter.gray75
        likeTitleLabel.text = "찜하기"

        likeCountLabel.font = TextStyle.Pretendard.title1
        likeCountLabel.textColor = .Feelter.gray30

        downloadCardView.backgroundColor = .Feelter.blackTurquoise
        downloadCardView.layer.cornerRadius = 12
        downloadCardView.layer.cornerCurve = .continuous

        likeCardView.backgroundColor = .Feelter.blackTurquoise
        likeCardView.layer.cornerRadius = 12
        likeCardView.layer.cornerCurve = .continuous

        compareGestureView.backgroundColor = .clear
        compareGestureView.addGestureRecognizer(comparePanGesture)
        compareGestureView.addGestureRecognizer(compareTapGesture)

        imageContainerView.addGestureRecognizer(imagePanGesture)
        imageContainerView.addGestureRecognizer(imageTapGesture)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        compareImageView.reset()
        compareSlider.value = initialSliderValue
        compareSlider.isEnabled = true
        priceLabel.text = nil
        downloadCountLabel.text = nil
        likeCountLabel.text = nil
    }

    func configure(previewImages: [String], price: Int, likeCount: Int, buyerCount: Int) {
        let leadingImagePath = previewImages.first
        let trailingImagePath = previewImages.dropFirst().first
        compareImageView.configure(leadingImagePath: leadingImagePath, trailingImagePath: trailingImagePath)

        let hasTrailingImage = trailingImagePath?.isEmpty == false
        compareSlider.isEnabled = hasTrailingImage
        sliderLineView.alpha = hasTrailingImage ? 1.0 : 0.35
        compareSlider.value = initialSliderValue
        compareImageView.updateSliderValue(CGFloat(initialSliderValue))
        updateCompareControlPosition()

        priceLabel.text = formattedNumber(price)
        downloadCountLabel.text = "\(formattedNumber(buyerCount))+"
        likeCountLabel.text = formattedNumber(likeCount)
    }

    @objc private func sliderValueChanged() {
        compareImageView.updateSliderValue(CGFloat(compareSlider.value))
        updateCompareControlPosition()
        contentView.layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCompareControlPosition()
    }

    private func formattedNumber(_ value: Int) -> String {
        let number = NSNumber(value: value)
        return Self.numberFormatter.string(from: number) ?? "\(value)"
    }

    private func updateCompareControlPosition() {
        let sliderWidth = compareGestureView.bounds.width
        guard sliderWidth > 0 else { return }

        compareControlView.layoutIfNeeded()
        let iconCenterX = compareIconContainerView.center.x
        guard iconCenterX > 0 else { return }

        let sliderX = sliderWidth * CGFloat(compareSlider.value)
        let leadingOffset = sliderX - iconCenterX
        compareControlLeadingConstraint?.update(offset: leadingOffset)
    }

    @objc private func handleComparePan(_ gesture: UIPanGestureRecognizer) {
        guard compareSlider.isEnabled else { return }
        let location = gesture.location(in: compareGestureView)
        updateSliderValue(forLocationX: location.x)
    }

    @objc private func handleCompareTap(_ gesture: UITapGestureRecognizer) {
        guard compareSlider.isEnabled else { return }
        let location = gesture.location(in: compareGestureView)
        updateSliderValue(forLocationX: location.x)
    }

    @objc private func handleImagePan(_ gesture: UIPanGestureRecognizer) {
        guard compareSlider.isEnabled else { return }
        let location = gesture.location(in: imageContainerView)
        updateSliderValue(forLocationX: location.x, width: imageContainerView.bounds.width)
    }

    @objc private func handleImageTap(_ gesture: UITapGestureRecognizer) {
        guard compareSlider.isEnabled else { return }
        let location = gesture.location(in: imageContainerView)
        updateSliderValue(forLocationX: location.x, width: imageContainerView.bounds.width)
    }

    private func updateSliderValue(forLocationX locationX: CGFloat, width: CGFloat? = nil) {
        let width = width ?? compareGestureView.bounds.width
        guard width > 0 else { return }
        let value = min(max(locationX / width, 0.0), 1.0)
        compareSlider.setValue(Float(value), animated: false)
        compareImageView.updateSliderValue(CGFloat(value))
        updateCompareControlPosition()
        contentView.layoutIfNeeded()
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }

        let velocity = panGesture.velocity(in: contentView)
        return abs(velocity.x) > abs(velocity.y)
    }

    private func makeTransparentThumbImage() -> UIImage {
        let size = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            UIColor.clear.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        }
    }
}

private final class FilterImageCompareView: UIView {
    private let leadingImageView = UIImageView()
    private let trailingImageView = UIImageView()
    private let dividerView = UIView()
    private let trailingMaskLayer = CALayer()
    private var sliderValue: CGFloat = 1.0
    private var currentLeadingPath: String?
    private var currentTrailingPath: String?
    private var needsImageReload = false
    private var lastLoadedSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(leadingImagePath: String?, trailingImagePath: String?) {
        currentLeadingPath = leadingImagePath
        currentTrailingPath = trailingImagePath
        needsImageReload = true

        let hasTrailingImage = trailingImagePath?.isEmpty == false
        trailingImageView.isHidden = !hasTrailingImage
        dividerView.isHidden = !hasTrailingImage
        updateSliderValue(1.0)
        loadImagesIfNeeded()
    }

    func updateSliderValue(_ value: CGFloat) {
        sliderValue = min(max(value, 0.0), 1.0)
        if bounds.width > 0, bounds.height > 0 {
            updateMaskFrame()
        } else {
            setNeedsLayout()
        }
    }

    func reset() {
        leadingImageView.image = nil
        trailingImageView.image = nil
        trailingImageView.isHidden = true
        dividerView.isHidden = true
        currentLeadingPath = nil
        currentTrailingPath = nil
        needsImageReload = false
        lastLoadedSize = .zero
        updateSliderValue(1.0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateMaskFrame()
        loadImagesIfNeeded()
    }

    private func configureHierarchy() {
        addSubview(leadingImageView)
        addSubview(trailingImageView)
        addSubview(dividerView)
    }

    private func configureLayout() {
        leadingImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        trailingImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func configureView() {
        clipsToBounds = true

        leadingImageView.contentMode = .scaleAspectFill
        trailingImageView.contentMode = .scaleAspectFill
        leadingImageView.backgroundColor = .Feelter.gray90
        trailingImageView.backgroundColor = .Feelter.gray90

        trailingMaskLayer.backgroundColor = UIColor.black.cgColor
        trailingImageView.layer.mask = trailingMaskLayer

        dividerView.backgroundColor = .clear
        dividerView.isHidden = true

        trailingMaskLayer.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
            "frame": NSNull()
        ]
        dividerView.layer.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
            "frame": NSNull()
        ]
    }

    private func loadImagesIfNeeded() {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        guard needsImageReload || lastLoadedSize != size else { return }

        lastLoadedSize = size
        needsImageReload = false

        leadingImageView.setFeelterImage(with: currentLeadingPath, targetSize: size)
        trailingImageView.setFeelterImage(with: currentTrailingPath, targetSize: size)
    }

    private func updateMaskFrame() {
        let width = bounds.width
        let height = bounds.height
        guard width > 0, height > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let dividerX = width * sliderValue
        trailingMaskLayer.frame = CGRect(
            x: dividerX,
            y: 0,
            width: width - dividerX,
            height: height
        )

        let dividerWidth: CGFloat = 1
        dividerView.frame = CGRect(
            x: dividerX - (dividerWidth / 2),
            y: 0,
            width: dividerWidth,
            height: height
        )

        CATransaction.commit()
    }
}
