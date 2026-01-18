//
//  FilterEditViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import UIKit
import SnapKit

@MainActor
final class FilterEditViewController: BaseViewController {
    private enum Layout {
        static let sliderHeight: CGFloat = 44
        static let horizontalInset: CGFloat = 20
        static let sliderTopSpacing: CGFloat = 34
        static let sliderBottomSpacing: CGFloat = 12
        static let propertyItemSpacing: CGFloat = 8
        static let propertyIconSize: CGFloat = 28
        static let actionButtonWidth: CGFloat = 40
        static let actionButtonHeight: CGFloat = 34
        static let actionButtonSpacing: CGFloat = 8
        static let actionButtonInset: CGFloat = 20
        static let propertyBarHeight: CGFloat = 60
    }

    private let selectedImage: UIImage
    private let imageContainerView = UIView()
    private let photoImageView = UIImageView()

    private let actionButtonStackView = UIStackView()
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    private let compareButton = UIButton(type: .system)

    private let adjustmentSlider = FilterAdjustmentSlider()
    private let propertyScrollView = UIScrollView()
    private let propertyStackView = UIStackView()

    private var propertyItemViews: [FilterAdjustmentProperty: FilterAdjustmentItemView] = [:]
    private var sliderValues: [FilterAdjustmentProperty: Float] = [:]
    private var selectedProperty: FilterAdjustmentProperty = .brightness

    init(image: UIImage) {
        self.selectedImage = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCustomTabBarHidden(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setCustomTabBarHidden(false)
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

        photoImageView.image = selectedImage
        photoImageView.contentMode = .scaleAspectFit
        photoImageView.clipsToBounds = true
        photoImageView.backgroundColor = .Feelter.gray100
        photoImageView.isUserInteractionEnabled = true

        configureActionButton(undoButton, image: UIImage.Icon.undo)
        configureActionButton(redoButton, image: UIImage.Icon.redo)
        configureActionButton(compareButton, image: UIImage.Icon.compare)

        actionButtonStackView.axis = .horizontal
        actionButtonStackView.alignment = .center
        actionButtonStackView.spacing = Layout.actionButtonSpacing

        adjustmentSlider.valueFormatter = { value in
            String(format: "%.1f", value)
        }
        adjustmentSlider.addTarget(self, action: #selector(adjustmentSliderValueChanged(_:)), for: .valueChanged)

        propertyScrollView.showsHorizontalScrollIndicator = false
        propertyScrollView.showsVerticalScrollIndicator = false
        propertyScrollView.alwaysBounceHorizontal = true
        propertyScrollView.alwaysBounceVertical = false
        propertyScrollView.contentInset = UIEdgeInsets(
            top: 0,
            left: Layout.horizontalInset,
            bottom: 0,
            right: Layout.horizontalInset
        )

        propertyStackView.axis = .horizontal
        propertyStackView.alignment = .center
        propertyStackView.distribution = .fill
        propertyStackView.spacing = Layout.propertyItemSpacing

        setupPropertyItems()
        selectProperty(selectedProperty, animated: false)
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(imageContainerView)
        imageContainerView.addSubview(photoImageView)
        imageContainerView.addSubview(actionButtonStackView)
        imageContainerView.addSubview(compareButton)
        view.addSubview(adjustmentSlider)
        view.addSubview(propertyScrollView)
        propertyScrollView.addSubview(propertyStackView)

        [undoButton, redoButton].forEach { button in
            actionButtonStackView.addArrangedSubview(button)
        }
    }

    override func configureLayout() {
        super.configureLayout()
        imageContainerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(adjustmentSlider.snp.top).offset(-Layout.sliderTopSpacing)
        }

        photoImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        adjustmentSlider.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(Layout.horizontalInset)
            make.bottom.equalTo(propertyScrollView.snp.top).offset(-Layout.sliderBottomSpacing)
            make.height.equalTo(Layout.sliderHeight)
        }

        propertyScrollView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(Layout.propertyBarHeight)
        }

        propertyStackView.snp.makeConstraints { make in
            make.edges.equalTo(propertyScrollView.contentLayoutGuide)
            make.height.equalTo(propertyScrollView.frameLayoutGuide)
        }

        actionButtonStackView.snp.makeConstraints { make in
            make.leading.equalTo(imageContainerView.snp.leading).inset(Layout.actionButtonInset)
            make.bottom.equalTo(imageContainerView.snp.bottom).inset(Layout.actionButtonInset)
        }

        [undoButton, redoButton].forEach { button in
            button.snp.makeConstraints { make in
                make.width.equalTo(Layout.actionButtonWidth)
                make.height.equalTo(Layout.actionButtonHeight)
            }
        }

        compareButton.snp.makeConstraints { make in
            make.trailing.equalTo(imageContainerView.snp.trailing).inset(Layout.actionButtonInset)
            make.bottom.equalTo(imageContainerView.snp.bottom).inset(Layout.actionButtonInset)
            make.width.equalTo(Layout.actionButtonWidth)
            make.height.equalTo(Layout.actionButtonHeight)
        }
    }

    @objc private func cancelButtonTapped() {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func saveButtonTapped() { }

    private func setCustomTabBarHidden(_ hidden: Bool) {
        (tabBarController as? CustomTabBarController)?.setCustomTabBarHidden(hidden, animated: false)
    }

    private func configureActionButton(_ button: UIButton, image: UIImage?) {
        button.setImage(image, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        button.imageView?.contentMode = .scaleAspectFit
        button.tintColor = .Feelter.gray75
        button.backgroundColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5)
        button.layer.cornerRadius = 10
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5).cgColor
    }

    private func setupPropertyItems() {
        sliderValues.removeAll()
        propertyItemViews.removeAll()
        propertyStackView.arrangedSubviews.forEach { itemView in
            propertyStackView.removeArrangedSubview(itemView)
            itemView.removeFromSuperview()
        }

        FilterAdjustmentProperty.ordered.forEach { property in
            let itemView = FilterAdjustmentItemView(property: property, iconSize: Layout.propertyIconSize)
            itemView.addTarget(self, action: #selector(propertyItemTapped(_:)), for: .touchUpInside)
            propertyItemViews[property] = itemView
            propertyStackView.addArrangedSubview(itemView)
            sliderValues[property] = property.defaultSliderValue
        }
    }

    private func selectProperty(_ property: FilterAdjustmentProperty, animated: Bool) {
        selectedProperty = property
        propertyItemViews.forEach { key, view in
            view.isSelected = key == property
        }

        adjustmentSlider.minimumValue = property.sliderMinimumValue
        adjustmentSlider.maximumValue = property.sliderMaximumValue
        adjustmentSlider.zeroSnapEnabled = property.supportsZeroSnap
        let sliderValue = sliderValues[property] ?? property.defaultSliderValue
        adjustmentSlider.setValue(sliderValue, animated: animated)
        adjustmentSlider.refresh()
    }

    @objc private func propertyItemTapped(_ sender: FilterAdjustmentItemView) {
        selectProperty(sender.property, animated: false)
    }

    @objc private func adjustmentSliderValueChanged(_ sender: FilterAdjustmentSlider) {
        sliderValues[selectedProperty] = sender.value
    }
}

private final class FilterAdjustmentItemView: UIControl {
    let property: FilterAdjustmentProperty
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let iconSize: CGFloat

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    init(property: FilterAdjustmentProperty, iconSize: CGFloat) {
        self.property = property
        self.iconSize = iconSize
        super.init(frame: .zero)
        configureHierarchy()
        configureLayout()
        configureView()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureHierarchy() {
        addSubview(iconImageView)
        addSubview(titleLabel)
    }

    private func configureLayout() {
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.height.equalTo(iconSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(6)
            make.centerX.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
    }

    private func configureView() {
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.image = property.icon?.withRenderingMode(.alwaysTemplate)

        titleLabel.text = property.title
        titleLabel.font = TextStyle.Pretendard.semibold2
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
    }

    override var intrinsicContentSize: CGSize {
        let labelSize = titleLabel.intrinsicContentSize
        let width = max(iconSize, labelSize.width) + 8
        let height = iconSize + 6 + labelSize.height
        return CGSize(width: width, height: height)
    }

    private func updateAppearance() {
        let color = isSelected ? UIColor.Feelter.gray30 : UIColor.Feelter.gray75
        iconImageView.tintColor = color
        titleLabel.textColor = color
    }
}

private final class FilterAdjustmentSlider: UISlider {
    private enum Layout {
        static let trackHeight: CGFloat = 12
        static let thumbSize: CGFloat = 4
        static let bubbleSpacing: CGFloat = 8
        static let trackCapExtension: CGFloat = 6
    }

    var valueFormatter: ((Float) -> String) = { value in
        String(format: "%.1f", value)
    }

    var zeroSnapEnabled = false
    var zeroSnapThreshold: Float = 0.2

    private let trackBackgroundView = UIView()
    private let gradientView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let gradientMaskLayer = CALayer()
    private let valueBubbleView = SliderValueBubbleView()
    private var previousValue: Float = 0
    private var feedbackGenerator: UISelectionFeedbackGenerator?

    override var minimumValue: Float {
        didSet { setNeedsLayout() }
    }

    override var maximumValue: Float {
        didSet { setNeedsLayout() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTrackLayout()
        updateBubblePosition()
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let defaultRect = super.trackRect(forBounds: bounds)
        let originY = defaultRect.midY - Layout.trackHeight / 2
        return CGRect(x: defaultRect.origin.x, y: originY, width: defaultRect.width, height: Layout.trackHeight)
    }

    override func setValue(_ value: Float, animated: Bool) {
        super.setValue(value, animated: false)
        updateTrackLayout()
        updateBubblePosition()
    }

    func refresh() {
        updateTrackLayout()
        updateBubblePosition()
    }

    private func configureView() {
        minimumTrackTintColor = .clear
        maximumTrackTintColor = .clear
        isContinuous = true

        trackBackgroundView.backgroundColor = .Feelter.blackTurquoise
        trackBackgroundView.layer.cornerRadius = Layout.trackHeight / 2
        trackBackgroundView.clipsToBounds = true

        gradientLayer.colors = [
            UIColor(hex: "#FF00B2")?.cgColor ?? UIColor.systemPink.cgColor,
            UIColor(hex: "#8D67AB")?.cgColor ?? UIColor.systemPurple.cgColor,
            UIColor(hex: "#73889C")?.cgColor ?? UIColor.systemBlue.cgColor,
            UIColor(hex: "#08CA8D")?.cgColor ?? UIColor.systemGreen.cgColor
        ]
        gradientLayer.locations = [0.0, 0.35, 0.7, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        gradientLayer.mask = gradientMaskLayer
        gradientMaskLayer.backgroundColor = UIColor.black.cgColor
        gradientMaskLayer.masksToBounds = true
        gradientMaskLayer.maskedCorners = [
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner
        ]
        gradientMaskLayer.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
            "frame": NSNull()
        ]

        gradientView.layer.addSublayer(gradientLayer)
        gradientView.layer.cornerRadius = Layout.trackHeight / 2
        gradientView.clipsToBounds = true

        insertSubview(trackBackgroundView, at: 0)
        insertSubview(gradientView, aboveSubview: trackBackgroundView)
        addSubview(valueBubbleView)

        valueBubbleView.isHidden = false

        let thumbImage = makeThumbImage()
        setThumbImage(thumbImage, for: .normal)
        setThumbImage(thumbImage, for: .highlighted)

        addTarget(self, action: #selector(handleValueChanged), for: .valueChanged)
        addTarget(self, action: #selector(handleTouchDown), for: .touchDown)
        addTarget(self, action: #selector(handleTouchDrag), for: [.touchDragInside, .touchDragOutside])
        addTarget(self, action: #selector(handleTouchEnd), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func handleTouchDown() {
        feedbackGenerator = UISelectionFeedbackGenerator()
        feedbackGenerator?.prepare()
        previousValue = value
    }

    @objc private func handleTouchDrag() {
    }

    @objc private func handleTouchEnd() {
        feedbackGenerator = nil
    }

    @objc private func handleValueChanged() {
        let didSnapToZero = applyZeroSnapIfNeeded()

        if zeroSnapEnabled {
            let crossedZero = (previousValue < 0 && value >= 0) || (previousValue > 0 && value <= 0)
            if didSnapToZero || crossedZero {
                feedbackGenerator?.selectionChanged()
                feedbackGenerator?.prepare()
            }
        }

        previousValue = value
        updateTrackLayout()
        updateBubblePosition()
    }

    private func updateTrackLayout() {
        let trackRect = self.trackRect(forBounds: bounds)
        trackBackgroundView.frame = trackRect
        gradientView.frame = trackRect
        gradientLayer.frame = gradientView.bounds

        let normalized = normalizedValue()
        let trackWidth = gradientView.bounds.width
        let baseWidth = trackWidth * normalized
        let extendedWidth: CGFloat
        if normalized <= 0 {
            extendedWidth = 0
        } else if normalized >= 1 {
            extendedWidth = trackWidth
        } else {
            extendedWidth = min(baseWidth + Layout.trackCapExtension, trackWidth)
        }
        gradientMaskLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: extendedWidth,
            height: gradientView.bounds.height
        )
        gradientMaskLayer.cornerRadius = gradientView.bounds.height / 2
    }

    private func normalizedValue() -> CGFloat {
        let range = maximumValue - minimumValue
        guard range > 0 else { return 0 }
        let normalized = (value - minimumValue) / range
        return CGFloat(min(max(normalized, 0), 1))
    }

    private func updateBubblePosition() {
        valueBubbleView.update(text: valueFormatter(value))
        valueBubbleView.sizeToFit()

        let trackRect = self.trackRect(forBounds: bounds)
        let thumbRect = self.thumbRect(forBounds: bounds, trackRect: trackRect, value: value)

        let bubbleSize = valueBubbleView.bounds.size
        let centeredX = thumbRect.midX - bubbleSize.width / 2
        let clampedX = min(max(0, centeredX), bounds.width - bubbleSize.width)
        let bubbleY = trackRect.minY - bubbleSize.height - Layout.bubbleSpacing

        valueBubbleView.frame = CGRect(x: clampedX, y: bubbleY, width: bubbleSize.width, height: bubbleSize.height)
    }

    private func applyZeroSnapIfNeeded() -> Bool {
        guard zeroSnapEnabled else { return false }
        guard abs(value) <= zeroSnapThreshold else { return false }
        guard value != 0 else { return false }
        setValue(0, animated: false)
        return true
    }

    private func makeThumbImage() -> UIImage {
        let size = CGSize(width: Layout.thumbSize, height: Layout.thumbSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(ovalIn: rect)
            UIColor.Feelter.blackTurquoise?.setFill()
            path.fill()
        }
    }
}

private final class SliderValueBubbleView: UIView {
    private enum Layout {
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 6
        static let cornerRadius: CGFloat = 8
    }

    private let valueLabel = UILabel()
    private let backgroundShapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let labelSize = valueLabel.intrinsicContentSize
        let width = labelSize.width + Layout.horizontalPadding * 2
        let height = labelSize.height + Layout.verticalPadding * 2
        return CGSize(width: width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let labelSize = valueLabel.intrinsicContentSize
        let bubbleWidth = labelSize.width + Layout.horizontalPadding * 2
        let bubbleHeight = labelSize.height + Layout.verticalPadding * 2
        let bubbleRect = CGRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight)
        valueLabel.frame = CGRect(
            x: Layout.horizontalPadding,
            y: Layout.verticalPadding,
            width: labelSize.width,
            height: labelSize.height
        )
        backgroundShapeLayer.path = UIBezierPath(
            roundedRect: bubbleRect,
            cornerRadius: Layout.cornerRadius
        ).cgPath
        backgroundShapeLayer.fillColor = UIColor.Feelter.blackTurquoise?.cgColor ?? UIColor.black.cgColor
    }

    func update(text: String) {
        valueLabel.text = text
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func sizeToFit() {
        let size = intrinsicContentSize
        frame.size = size
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func configureView() {
        addSubview(valueLabel)
        valueLabel.font = TextStyle.Pretendard.title2
        valueLabel.textColor = .Feelter.gray75
        valueLabel.textAlignment = .center
        isUserInteractionEnabled = false
        layer.insertSublayer(backgroundShapeLayer, at: 0)
    }
}
