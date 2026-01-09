//
//  FilterPresetsContainerView.swift
//  Feelter
//
//  Created by Suji Jang on 1/9/26.
//

import UIKit
import SnapKit

final class FilterPresetsContainerView: UIView {
    private enum Layout {
        static let rowSpacing: CGFloat = 16
        static let itemSpacing: CGFloat = 12
        static let itemsPerRow: Int = 6
        static let lockIconSize: CGFloat = 32
    }

    private enum TemperatureRange {
        static let minKelvin: Double = 2000
        static let maxKelvin: Double = 10000
        static let midKelvin: Double = 6000
    }

    private let cardView = FilterDetailCardContainerView()
    private let rowsStackView = UIStackView()
    private let lockOverlayView = UIView()
    private let lockBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
    private let lockStackView = UIStackView()
    private let lockIconImageView = UIImageView()
    private let lockMessageLabel = UILabel()
    private var itemViews: [FilterPresetItemView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(values: FilterValues?) {
        cardView.configure(title: "Filter Presets", tag: "LUT")
        let items = makePresetItems(from: values)
        for (index, view) in itemViews.enumerated() {
            guard index < items.count else { continue }
            view.configure(icon: items[index].icon, valueText: items[index].valueText)
        }
    }

    func setLocked(_ isLocked: Bool) {
        lockOverlayView.isHidden = !isLocked
        cardView.overlayView.isUserInteractionEnabled = isLocked
    }

    func reset() {
        cardView.configure(title: "Filter Presets", tag: "LUT")
        for view in itemViews {
            view.configure(icon: nil, valueText: "-")
        }
        setLocked(false)
    }

    private func configureHierarchy() {
        addSubview(cardView)
        cardView.contentView.addSubview(rowsStackView)
        cardView.overlayView.addSubview(lockOverlayView)
        lockOverlayView.addSubview(lockBlurView)
        lockOverlayView.addSubview(lockStackView)
        lockStackView.addArrangedSubview(lockIconImageView)
        lockStackView.addArrangedSubview(lockMessageLabel)

        for _ in 0..<(Layout.itemsPerRow * 2) {
            let view = FilterPresetItemView()
            itemViews.append(view)
        }

        for rowIndex in 0..<2 {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.alignment = .center
            rowStackView.distribution = .fillEqually
            rowStackView.spacing = Layout.itemSpacing
            rowsStackView.addArrangedSubview(rowStackView)

            let startIndex = rowIndex * Layout.itemsPerRow
            let endIndex = startIndex + Layout.itemsPerRow
            for index in startIndex..<endIndex {
                rowStackView.addArrangedSubview(itemViews[index])
            }
        }
    }

    private func configureLayout() {
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        rowsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        lockOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        lockBlurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        lockStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        lockIconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.lockIconSize)
        }
    }

    private func configureView() {
        rowsStackView.axis = .vertical
        rowsStackView.alignment = .fill
        rowsStackView.distribution = .fillEqually
        rowsStackView.spacing = Layout.rowSpacing

        lockOverlayView.isHidden = true
        lockOverlayView.backgroundColor = UIColor.Feelter.blackTurquoise?.withAlphaComponent(0.9)
        lockBlurView.alpha = 0.95

        lockStackView.axis = .vertical
        lockStackView.alignment = .center
        lockStackView.spacing = 12

        lockIconImageView.contentMode = .scaleAspectFit
        lockIconImageView.tintColor = .Feelter.gray45
        lockIconImageView.image = UIImage.Icon.lock?.withRenderingMode(.alwaysTemplate)

        lockMessageLabel.font = TextStyle.Pretendard.body2
        lockMessageLabel.textColor = .Feelter.gray45
        lockMessageLabel.textAlignment = .center
        lockMessageLabel.numberOfLines = 2
        lockMessageLabel.text = "결제가 필요한 유료 필터입니다"
    }

    private func makePresetItems(from values: FilterValues?) -> [PresetItem] {
        guard let values else {
            return emptyPresetItems()
        }

        return [
            PresetItem(icon: UIImage.FilterProps.brightness, valueText: formattedValue(values.brightness)),
            PresetItem(icon: UIImage.FilterProps.exposure, valueText: formattedValue(values.exposure)),
            PresetItem(icon: UIImage.FilterProps.contrast, valueText: formattedValue(values.contrast)),
            PresetItem(icon: UIImage.FilterProps.saturation, valueText: formattedValue(values.saturation)),
            PresetItem(icon: UIImage.FilterProps.sharpness, valueText: formattedValue(values.sharpness)),
            PresetItem(icon: UIImage.FilterProps.noise, valueText: formattedValue(values.noiseReduction)),
            PresetItem(icon: UIImage.FilterProps.vignette, valueText: formattedValue(values.vignette)),
            PresetItem(icon: UIImage.FilterProps.blur, valueText: formattedValue(values.blur)),
            PresetItem(icon: UIImage.FilterProps.highlights, valueText: formattedValue(values.highlights)),
            PresetItem(icon: UIImage.FilterProps.shadows, valueText: formattedValue(values.shadows)),
            PresetItem(icon: UIImage.FilterProps.temperature, valueText: formattedTemperature(values.temperature)),
            PresetItem(icon: UIImage.FilterProps.blackPoint, valueText: formattedValue(values.blackPoint))
        ]
    }

    private func emptyPresetItems() -> [PresetItem] {
        return (0..<(Layout.itemsPerRow * 2)).map { _ in
            PresetItem(icon: nil, valueText: "-")
        }
    }

    private func formattedValue(_ value: Double) -> String {
        return String(format: "%.1f", value)
    }

    private func formattedTemperature(_ kelvin: Double) -> String {
        let minKelvin = TemperatureRange.minKelvin
        let maxKelvin = TemperatureRange.maxKelvin
        let midKelvin = TemperatureRange.midKelvin

        guard maxKelvin > minKelvin, midKelvin >= minKelvin, midKelvin <= maxKelvin else {
            return formattedValue(kelvin)
        }

        let normalized: Double
        if kelvin >= midKelvin {
            let denominator = maxKelvin - midKelvin
            normalized = denominator > 0 ? (kelvin - midKelvin) / denominator : 0
        } else {
            let denominator = midKelvin - minKelvin
            normalized = denominator > 0 ? (kelvin - midKelvin) / denominator : 0
        }

        let clamped = min(max(normalized, -1.0), 1.0)
        return String(format: "%.1f", clamped)
    }
}

private struct PresetItem {
    let icon: UIImage?
    let valueText: String
}

private final class FilterPresetItemView: UIView {
    private enum Layout {
        static let iconSize: CGFloat = 32
        static let valueSpacing: CGFloat = 8
    }

    private let stackView = UIStackView()
    private let iconImageView = UIImageView()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon: UIImage?, valueText: String) {
        iconImageView.image = icon?.withRenderingMode(.alwaysTemplate)
        valueLabel.text = valueText
    }

    private func configureHierarchy() {
        addSubview(stackView)
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(valueLabel)
    }

    private func configureLayout() {
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.iconSize)
        }
    }

    private func configureView() {
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Layout.valueSpacing

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .Feelter.gray30

        valueLabel.font = TextStyle.Pretendard.body2
        valueLabel.textColor = .Feelter.gray75
        valueLabel.textAlignment = .center
    }
}
