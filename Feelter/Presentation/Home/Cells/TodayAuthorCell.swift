//
//  TodayAuthorCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/20/26.
//

import UIKit
import SnapKit

final class TodayAuthorCell: BaseCollectionViewCell {

    var onFilterTapped: ((FilterSummary) -> Void)?

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let verticalSpacing: CGFloat = 16
        static let profileSize: CGFloat = 72
        static let filterHeight: CGFloat = 96
        static let filterSpacing: CGFloat = 12
        static let filterItemSize = CGSize(width: 148, height: 96)
    }

    private var filters: [FilterSummary] = []

    private let profileImageView = UIImageView()
    private let nameLabel = UILabel()
    private let nicknameLabel = UILabel()
    private let tagWrapView = TagWrapView()
    private let introductionLabel = UILabel()
    private let descriptionLabel = UILabel()

    private lazy var nameStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, nicknameLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        return stackView
    }()

    private lazy var filtersCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = Layout.filterSpacing
        layout.itemSize = Layout.filterItemSize

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            TodayAuthorFilterCell.self,
            forCellWithReuseIdentifier: TodayAuthorFilterCell.identifier
        )
        return collectionView
    }()

    override func configureHierarchy() {
        contentView.addSubview(profileImageView)
        contentView.addSubview(nameStackView)
        contentView.addSubview(filtersCollectionView)
        contentView.addSubview(tagWrapView)
        contentView.addSubview(introductionLabel)
        contentView.addSubview(descriptionLabel)
    }

    override func configureLayout() {
        profileImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.size.equalTo(Layout.profileSize)
        }

        nameStackView.snp.makeConstraints { make in
            make.leading.equalTo(profileImageView.snp.trailing).offset(Layout.verticalSpacing)
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.centerY.equalTo(profileImageView)
        }

        filtersCollectionView.snp.makeConstraints { make in
            make.top.equalTo(profileImageView.snp.bottom).offset(Layout.verticalSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.filterHeight)
        }

        tagWrapView.snp.makeConstraints { make in
            make.top.equalTo(filtersCollectionView.snp.bottom).offset(Layout.verticalSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        introductionLabel.snp.makeConstraints { make in
            make.top.equalTo(tagWrapView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(introductionLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().inset(24)
        }
    }

    override func configureView() {
        super.configureView()

        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = Layout.profileSize / 2
        profileImageView.layer.borderWidth = 1
        profileImageView.layer.borderColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5).cgColor
        profileImageView.backgroundColor = .Feelter.gray100

        nameLabel.font = TextStyle.Mulgyeol.body1
        nameLabel.textColor = .Feelter.gray30

        nicknameLabel.font = TextStyle.Pretendard.body1
        nicknameLabel.textColor = .Feelter.gray75

        introductionLabel.font = TextStyle.Mulgyeol.caption1
        introductionLabel.textColor = .Feelter.gray60
        introductionLabel.numberOfLines = 0

        descriptionLabel.font = TextStyle.Pretendard.caption2
        descriptionLabel.textColor = .Feelter.gray60
        descriptionLabel.numberOfLines = 0
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = UIImage(named: "appIcon")
        nameLabel.text = nil
        nicknameLabel.text = nil
        introductionLabel.text = nil
        descriptionLabel.text = nil
        introductionLabel.isHidden = false
        tagWrapView.configure(tags: [])
        filters = []
        onFilterTapped = nil
        filtersCollectionView.reloadData()
        filtersCollectionView.setContentOffset(.zero, animated: false)
    }

    func configure(with todayAuthor: TodayAuthor) {
        let author = todayAuthor.author

        nameLabel.text = author.name
        nicknameLabel.text = author.nickname
        tagWrapView.configure(tags: author.hashTags)

        if author.introduction.isEmpty {
            introductionLabel.text = nil
            introductionLabel.isHidden = true
        } else {
            introductionLabel.text = "\"\(author.introduction)\""
            introductionLabel.isHidden = false
        }

        descriptionLabel.text = author.description

        profileImageView.image = UIImage(named: "appIcon")
        profileImageView.backgroundColor = .clear
        if let path = author.profileImageURL, !path.isEmpty {
            profileImageView.setFeelterImage(with: path)
        }

        filters = todayAuthor.filters
        filtersCollectionView.reloadData()
        filtersCollectionView.setContentOffset(.zero, animated: false)
    }
}

extension TodayAuthorCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        filters.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TodayAuthorFilterCell.identifier,
            for: indexPath
        ) as? TodayAuthorFilterCell else {
            return UICollectionViewCell()
        }

        cell.configure(with: filters[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onFilterTapped?(filters[indexPath.item])
    }
}

private final class TodayAuthorFilterCell: UICollectionViewCell {

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        contentView.addSubview(imageView)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 4
        imageView.backgroundColor = .Feelter.gray90
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }

    func configure(with filter: FilterSummary) {
        imageView.setFeelterImage(with: filter.mainImageURL)
    }
}

private final class TagWrapView: UIView {
    private enum Layout {
        static let horizontalSpacing: CGFloat = 8
        static let verticalSpacing: CGFloat = 8
    }

    private var tagLabels: [CapsuleLabel] = []
    private var cachedSize: CGSize = .zero

    func configure(tags: [String]) {
        tagLabels.forEach { $0.removeFromSuperview() }
        tagLabels.removeAll()

        for tag in tags {
            let label = CapsuleLabel(padding: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))
            label.font = TextStyle.Pretendard.caption2
            label.textColor = .Feelter.gray60
            label.backgroundColor = .Feelter.blackTurquoise
            label.text = tag.hasPrefix("#") ? tag : "#\(tag)"
            addSubview(label)
            tagLabels.append(label)
        }

        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutTagLabels()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let targetWidth = size.width > 0 ? size.width : bounds.width
        guard targetWidth > 0 else { return .zero }
        return computeSize(forWidth: targetWidth)
    }

    override var intrinsicContentSize: CGSize {
        if bounds.width > 0 {
            return computeSize(forWidth: bounds.width)
        }
        return cachedSize
    }

    private func layoutTagLabels() {
        let maxWidth = bounds.width
        guard maxWidth > 0 else { return }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for label in tagLabels {
            let labelSize = label.intrinsicContentSize
            if x + labelSize.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + Layout.verticalSpacing
                rowHeight = 0
            }

            label.frame = CGRect(x: x, y: y, width: labelSize.width, height: labelSize.height)
            x += labelSize.width + Layout.horizontalSpacing
            rowHeight = max(rowHeight, labelSize.height)
        }

        let totalHeight = rowHeight > 0 ? y + rowHeight : 0
        let newSize = CGSize(width: maxWidth, height: totalHeight)
        if cachedSize != newSize {
            cachedSize = newSize
            invalidateIntrinsicContentSize()
        }
    }

    private func computeSize(forWidth width: CGFloat) -> CGSize {
        guard width > 0 else { return .zero }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for label in tagLabels {
            let labelSize = label.intrinsicContentSize
            if x + labelSize.width > width, x > 0 {
                x = 0
                y += rowHeight + Layout.verticalSpacing
                rowHeight = 0
            }
            x += labelSize.width + Layout.horizontalSpacing
            rowHeight = max(rowHeight, labelSize.height)
        }

        let totalHeight = rowHeight > 0 ? y + rowHeight : 0
        return CGSize(width: width, height: totalHeight)
    }
}
