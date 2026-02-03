//
//  UIImage+Watermark.swift
//  Feelter
//
//  Created by Suji Jang on 2/3/26.
//

import UIKit

extension UIImage {

    /// 이미지에 워터마크를 추가합니다 (오른쪽 하단)
    /// - Parameters:
    ///   - filterName: 필터 이름
    ///   - creatorNickname: 작가 닉네임
    ///   - filterThumbnail: 필터 썸네일 이미지 (90x90)
    /// - Returns: 워터마크가 추가된 이미지
    func addingWatermark(
        filterName: String,
        creatorNickname: String,
        filterThumbnail: UIImage?
    ) -> UIImage {
        let baseImage = normalizedForWatermark()
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = baseImage.scale
        rendererFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: rendererFormat)

        return renderer.image { context in
            // 1. 원본 이미지 그리기
            baseImage.draw(at: .zero)

            // 2. 워터마크 뷰 생성
            let watermarkView = createWatermarkView(
                filterName: filterName,
                creatorNickname: creatorNickname,
                filterThumbnail: filterThumbnail
            )

            // 3. 워터마크 크기 계산
            let maxSize = CGSize(width: baseImage.size.width * 0.8, height: baseImage.size.height * 0.3)
            let watermarkSize = watermarkView.systemLayoutSizeFitting(
                maxSize,
                withHorizontalFittingPriority: .fittingSizeLevel,
                verticalFittingPriority: .fittingSizeLevel
            )

            // 4. 오른쪽 하단에 배치 (오른쪽 0pt, 아래 8pt)
            let paddingRight: CGFloat = 0
            let paddingBottom: CGFloat = 8
            let origin = CGPoint(
                x: max(0, baseImage.size.width - watermarkSize.width - paddingRight),
                y: max(0, baseImage.size.height - watermarkSize.height - paddingBottom)
            )

            // 5. 워터마크 렌더링
            watermarkView.frame = CGRect(origin: origin, size: watermarkSize)
            watermarkView.layoutIfNeeded()
            watermarkView.layer.render(in: context.cgContext)
        }
    }

    /// 워터마크 UI 뷰 생성
    /// 레이아웃:
    ///   [필터 이름]     [필터 이미지]
    ///   [작가 닉네임]   [          ]
    private func createWatermarkView(
        filterName: String,
        creatorNickname: String,
        filterThumbnail: UIImage?
    ) -> UIView {
        let containerView = UIView()

        // 반투명 검은 배경
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        backgroundView.layer.cornerRadius = 0
        backgroundView.clipsToBounds = true
        containerView.addSubview(backgroundView)

        // 텍스트 스택 (필터 이름 + 작가 닉네임) - 왼쪽 정렬
        let textStackView = UIStackView()
        textStackView.axis = .vertical
        textStackView.alignment = .leading  // 왼쪽 정렬
        textStackView.spacing = 3  // 1.5배

        // 필터 이름 - Mulgyeol 제일 작은 글씨 (14pt → 21pt로 1.5배)
        let filterNameLabel = UILabel()
        filterNameLabel.text = filterName
        filterNameLabel.font = AppFont.Mulgyeol.regular(21)  // 14 * 1.5 = 21
        filterNameLabel.textColor = .white
        filterNameLabel.numberOfLines = 1
        filterNameLabel.textAlignment = .left

        // 작가 닉네임 - Pretendard (12pt → 18pt로 1.5배)
        let creatorLabel = UILabel()
        creatorLabel.text = creatorNickname
        creatorLabel.font = AppFont.Pretendard.regular(18)  // 12 * 1.5 = 18
        creatorLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        creatorLabel.numberOfLines = 1
        creatorLabel.textAlignment = .left

        textStackView.addArrangedSubview(filterNameLabel)
        textStackView.addArrangedSubview(creatorLabel)

        // 필터 썸네일 이미지 (45x45 - 1.5배)
        let thumbnailImageView = UIImageView()
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 0
        thumbnailImageView.backgroundColor = UIColor.white.withAlphaComponent(0.2)

        if let thumbnail = filterThumbnail {
            thumbnailImageView.image = thumbnail
        } else {
            // Placeholder 이미지
            thumbnailImageView.image = UIImage(systemName: "photo.fill")
            thumbnailImageView.tintColor = .white
            thumbnailImageView.contentMode = .center
        }

        // 가로 스택 (썸네일 + 텍스트) - 순서 변경
        let horizontalStackView = UIStackView(arrangedSubviews: [thumbnailImageView, textStackView])
        horizontalStackView.axis = .horizontal
        horizontalStackView.alignment = .center
        horizontalStackView.spacing = 9  // 1.5배
        horizontalStackView.layoutMargins = UIEdgeInsets(top: 9, left: 12, bottom: 9, right: 12)  // 1.5배
        horizontalStackView.isLayoutMarginsRelativeArrangement = true

        containerView.addSubview(horizontalStackView)

        // 레이아웃 설정
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // 배경뷰는 컨테이너 전체
            backgroundView.topAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // 스택뷰는 컨테이너에 맞춤
            horizontalStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            horizontalStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            horizontalStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            horizontalStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // 썸네일 크기 고정 (45x45 - 1.5배)
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 45),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 45)
        ])

        return containerView
    }

    /// 워터마크 적용 전에 이미지 방향을 정규화합니다.
    private func normalizedForWatermark() -> UIImage {
        guard imageOrientation != .up else { return self }
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = scale
        rendererFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
