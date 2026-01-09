//
//  FilterMetadataContainerView.swift
//  Feelter
//
//  Created by Suji Jang on 1/9/26.
//

import UIKit
import SnapKit
import MapKit
import CoreLocation

final class FilterMetadataContainerView: UIView {
    private enum Layout {
        static let headerHeight: CGFloat = 34
        static let horizontalInset: CGFloat = 12
        static let labelSpacing: CGFloat = 8
        static let dividerHeight: CGFloat = 1
        static let contentInset: CGFloat = 12
        static let mapSize: CGFloat = 72
        static let contentSpacing: CGFloat = 12
        static let placeholderImageSize: CGFloat = 28
    }

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let tagLabel = UILabel()
    private let dividerView = UIView()
    private let contentView = UIView()
    private let mapContainerView = UIView()
    private let mapView = MKMapView()
    private let mapPlaceholderView = UIView()
    private let mapPlaceholderStackView = UIStackView()
    private let mapPlaceholderImageView = UIImageView()
    private let mapPlaceholderLabel = UILabel()
    private let infoStackView = UIStackView()
    private let primaryInfoLabel = UILabel()
    private let secondaryInfoLabel = UILabel()
    private let locationLabel = UILabel()
    private let geocoder = CLGeocoder()
    private var currentCoordinate: CLLocationCoordinate2D?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, tag: String) {
        titleLabel.text = title
        tagLabel.text = tag
    }

    func configure(metadata: PhotoMetadata) {
        configure(title: metadata.camera, tag: "EXIF")
        primaryInfoLabel.text = makePrimaryInfoText(metadata)
        secondaryInfoLabel.text = makeSecondaryInfoText(metadata)
        updateMapAndAddress(latitude: metadata.latitude, longitude: metadata.longitude)
    }

    func reset() {
        geocoder.cancelGeocode()
        currentCoordinate = nil
        mapView.removeAnnotations(mapView.annotations)
        mapView.isHidden = true
        mapPlaceholderView.isHidden = false
        primaryInfoLabel.text = nil
        secondaryInfoLabel.text = nil
        locationLabel.text = nil
    }

    private func configureHierarchy() {
        addSubview(headerView)
        addSubview(dividerView)
        addSubview(contentView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(tagLabel)
        contentView.addSubview(mapContainerView)
        contentView.addSubview(infoStackView)
        mapContainerView.addSubview(mapView)
        mapContainerView.addSubview(mapPlaceholderView)
        mapPlaceholderView.addSubview(mapPlaceholderStackView)
        mapPlaceholderStackView.addArrangedSubview(mapPlaceholderImageView)
        mapPlaceholderStackView.addArrangedSubview(mapPlaceholderLabel)
        infoStackView.addArrangedSubview(primaryInfoLabel)
        infoStackView.addArrangedSubview(secondaryInfoLabel)
        infoStackView.addArrangedSubview(locationLabel)
    }

    private func configureLayout() {
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.headerHeight)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(tagLabel.snp.leading).offset(-Layout.labelSpacing)
        }

        tagLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.centerY.equalToSuperview()
        }

        dividerView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.dividerHeight)
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(dividerView.snp.bottom).offset(Layout.contentInset)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().inset(Layout.contentInset)
        }

        mapContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(mapContainerView.snp.height)
        }

        mapView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        mapPlaceholderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        mapPlaceholderStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        mapPlaceholderImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.placeholderImageSize)
        }

        infoStackView.snp.makeConstraints { make in
            make.leading.equalTo(mapContainerView.snp.trailing).offset(Layout.contentSpacing)
            make.trailing.equalToSuperview()
            make.centerY.equalTo(mapContainerView)
        }
    }

    private func configureView() {
        backgroundColor = .Feelter.blackTurquoise
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 2
        layer.borderColor = UIColor.Feelter.blackTurquoise?.cgColor
        clipsToBounds = true

        headerView.backgroundColor = .Feelter.gray100

        titleLabel.font = TextStyle.Pretendard.title2
        titleLabel.textColor = .Feelter.gray75

        tagLabel.font = TextStyle.Pretendard.title2
        tagLabel.textColor = .Feelter.gray75
        tagLabel.text = "EXIF"

        dividerView.backgroundColor = .Feelter.blackTurquoise

        mapContainerView.backgroundColor = .Feelter.blackTurquoise
        mapContainerView.layer.borderColor = UIColor.Feelter.deepTurquoise?.cgColor
        mapContainerView.layer.borderWidth = 2
        mapContainerView.layer.cornerRadius = 8
        mapContainerView.layer.cornerCurve = .continuous
        mapContainerView.clipsToBounds = true

        mapView.isUserInteractionEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = false
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        mapView.isHidden = true

        mapPlaceholderView.backgroundColor = .Feelter.blackTurquoise
        mapPlaceholderView.layer.borderColor = UIColor.Feelter.deepTurquoise?.cgColor
        mapPlaceholderView.layer.borderWidth = 2
        mapPlaceholderView.layer.cornerRadius = 8
        
        mapPlaceholderStackView.axis = .vertical
        mapPlaceholderStackView.alignment = .center
        mapPlaceholderStackView.spacing = 6

        mapPlaceholderImageView.contentMode = .scaleAspectFit
        mapPlaceholderImageView.tintColor = .Feelter.deepTurquoise
        mapPlaceholderImageView.image = UIImage.Icon.noLocation?.withRenderingMode(.alwaysTemplate)

        mapPlaceholderLabel.font = TextStyle.Pretendard.semibold2
        mapPlaceholderLabel.textColor = .Feelter.deepTurquoise
        mapPlaceholderLabel.text = "No Location"

        infoStackView.axis = .vertical
        infoStackView.alignment = .leading
        infoStackView.spacing = 6

        primaryInfoLabel.font = TextStyle.Pretendard.semibold1
        primaryInfoLabel.textColor = .Feelter.gray75
        primaryInfoLabel.numberOfLines = 1

        secondaryInfoLabel.font = TextStyle.Pretendard.semibold1
        secondaryInfoLabel.textColor = .Feelter.gray75
        secondaryInfoLabel.numberOfLines = 2

        locationLabel.font = TextStyle.Pretendard.semibold1
        locationLabel.textColor = .Feelter.gray75
        locationLabel.numberOfLines = 2
    }

    private func makePrimaryInfoText(_ metadata: PhotoMetadata) -> String {
        let lensInfo = metadata.lensInfo.isEmpty ? "-" : metadata.lensInfo
        let focalLengthText = metadata.focalLength > 0 ? "\(metadata.focalLength)" : "-"
        let apertureText = metadata.aperture > 0 ? String(format: "%.1f", metadata.aperture) : "-"
        let isoText = metadata.iso > 0 ? "\(metadata.iso)" : "-"
        return "\(lensInfo) - \(focalLengthText) mm 𝒇 \(apertureText) ISO \(isoText)"
    }

    private func makeSecondaryInfoText(_ metadata: PhotoMetadata) -> String {
        let totalPixels = metadata.pixelWidth * metadata.pixelHeight
        let megaPixelsText = totalPixels > 0
        ? String(format: "%.0f", Double(totalPixels) / 1_000_000)
        : "-"

        let resolutionText = metadata.pixelWidth > 0 && metadata.pixelHeight > 0
        ? "\(metadata.pixelWidth) x \(metadata.pixelHeight)"
        : "-"

        let fileSizeText = metadata.fileSizeBytes > 0
        ? String(format: "%.1f", Double(metadata.fileSizeBytes) / 1_000_000)
        : "-"

        return "\(megaPixelsText)MP • \(resolutionText) • \(fileSizeText)MB"
    }

    private func updateMapAndAddress(latitude: Double?, longitude: Double?) {
        guard let latitude, let longitude else {
            mapView.isHidden = true
            mapPlaceholderView.isHidden = false
            locationLabel.text = "위치 정보 없음"
            return
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        currentCoordinate = coordinate
        mapView.isHidden = false
        mapPlaceholderView.isHidden = true

        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: false)
        mapView.removeAnnotations(mapView.annotations)

        updateAddressText(for: coordinate)
    }

    private func updateAddressText(for coordinate: CLLocationCoordinate2D) {
        geocoder.cancelGeocode()
        locationLabel.text = "위치 정보 불러오는 중..."

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            guard self.currentCoordinate?.latitude == coordinate.latitude,
                  self.currentCoordinate?.longitude == coordinate.longitude else {
                return
            }

            let address = placemarks?.first.flatMap { self.makeAddressText(from: $0) }
            DispatchQueue.main.async {
                self.locationLabel.text = address ?? "위치 정보 없음"
            }
        }
    }

    private func makeAddressText(from placemark: CLPlacemark) -> String? {
        let parts = [
            placemark.administrativeArea,
            placemark.locality,
            placemark.subLocality,
            placemark.thoroughfare,
            placemark.subThoroughfare
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }

        return placemark.name
    }
}
