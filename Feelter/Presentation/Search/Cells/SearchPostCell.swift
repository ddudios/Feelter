//
//  SearchPostCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/21/26.
//

import UIKit
import SnapKit

final class SearchPostCell: UITableViewCell {

    var onLikeTapped: ((String, Bool) -> Void)?

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let verticalInset: CGFloat = 16
        static let profileSize: CGFloat = 36
        static let imageHeight: CGFloat = 320
        static let iconSize: CGFloat = 22
        static let commentIconSize: CGFloat = 18
        static let titleSpacing: CGFloat = 8
        static let smallSpacing: CGFloat = 6
        static let sectionSpacing: CGFloat = 12
    }

    private let profileImageView = UIImageView()
    private let authorNameLabel = UILabel()
    private let locationLabel = UILabel()

    private let imageCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .Feelter.gray90
        collectionView.register(SearchPostImageCell.self, forCellWithReuseIdentifier: SearchPostImageCell.identifier)
        return collectionView
    }()

    private let pageControl = UIPageControl()

    private let likeButton = UIButton(type: .custom)
    private let likeCountLabel = UILabel()
    private let commentIconImageView = UIImageView()
    private let commentCountLabel = UILabel()

    private let titleLabel = UILabel()
    private let categoryLabel = CapsuleLabel()
    private let contentLabel = UILabel()
    private let timeLabel = UILabel()

    private lazy var titleStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, categoryLabel])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = Layout.titleSpacing
        return stackView
    }()

    private var imagePaths: [String] = []
    private var currentPostId: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let layout = imageCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let size = CGSize(width: imageCollectionView.bounds.width, height: imageCollectionView.bounds.height)
            if layout.itemSize != size {
                layout.itemSize = size
                layout.invalidateLayout()
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentPostId = nil
        imagePaths = []
        profileImageView.image = UIImage(named: "appIcon")
        authorNameLabel.text = nil
        locationLabel.text = nil
        likeCountLabel.text = nil
        commentCountLabel.text = nil
        titleLabel.text = nil
        categoryLabel.text = nil
        contentLabel.text = nil
        timeLabel.text = nil
        likeButton.isSelected = false
        pageControl.currentPage = 0
        pageControl.numberOfPages = 0
        imageCollectionView.setContentOffset(.zero, animated: false)
        imageCollectionView.reloadData()
    }

    func configure(with item: SearchPostItem) {
        currentPostId = item.id
        imagePaths = item.imagePaths

        profileImageView.image = UIImage(named: "appIcon")
        if let path = item.profileImagePath, !path.isEmpty {
            profileImageView.setFeelterImage(with: path)
        }

        authorNameLabel.text = item.authorName
        locationLabel.text = item.locationText
        locationLabel.isHidden = item.locationText == nil

        likeButton.isSelected = item.isLiked
        likeCountLabel.text = "\(item.likeCount)"
        commentCountLabel.text = "\(item.commentCount)"

        titleLabel.text = item.title
        categoryLabel.text = "#\(item.category)"
        contentLabel.text = item.content
        timeLabel.text = item.timeText

        pageControl.numberOfPages = imagePaths.count
        pageControl.isHidden = imagePaths.count <= 1
        pageControl.currentPage = 0
        imageCollectionView.reloadData()
    }

    private func configureHierarchy() {
        contentView.addSubview(profileImageView)
        contentView.addSubview(authorNameLabel)
        contentView.addSubview(locationLabel)
        contentView.addSubview(imageCollectionView)
        contentView.addSubview(pageControl)
        contentView.addSubview(likeButton)
        contentView.addSubview(likeCountLabel)
        contentView.addSubview(commentIconImageView)
        contentView.addSubview(commentCountLabel)
        contentView.addSubview(titleStackView)
        contentView.addSubview(contentLabel)
        contentView.addSubview(timeLabel)
    }

    private func configureLayout() {
        profileImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Layout.verticalInset)
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.size.equalTo(Layout.profileSize)
        }

        authorNameLabel.snp.makeConstraints { make in
            make.top.equalTo(profileImageView.snp.top)
            make.leading.equalTo(profileImageView.snp.trailing).offset(Layout.sectionSpacing)
            make.trailing.lessThanOrEqualToSuperview().inset(Layout.horizontalInset)
        }

        locationLabel.snp.makeConstraints { make in
            make.top.equalTo(authorNameLabel.snp.bottom).offset(4)
            make.leading.equalTo(authorNameLabel)
            make.trailing.lessThanOrEqualToSuperview().inset(Layout.horizontalInset)
        }

        imageCollectionView.snp.makeConstraints { make in
            make.top.equalTo(profileImageView.snp.bottom).offset(Layout.sectionSpacing)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.imageHeight)
        }

        pageControl.snp.makeConstraints { make in
            make.top.equalTo(imageCollectionView.snp.bottom).offset(Layout.smallSpacing)
            make.centerX.equalToSuperview()
        }

        likeButton.snp.makeConstraints { make in
            make.top.equalTo(pageControl.snp.bottom).offset(Layout.sectionSpacing)
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.size.equalTo(Layout.iconSize)
        }

        likeCountLabel.snp.makeConstraints { make in
            make.centerY.equalTo(likeButton)
            make.leading.equalTo(likeButton.snp.trailing).offset(Layout.smallSpacing)
        }

        commentIconImageView.snp.makeConstraints { make in
            make.centerY.equalTo(likeButton)
            make.leading.equalTo(likeCountLabel.snp.trailing).offset(Layout.sectionSpacing)
            make.size.equalTo(Layout.commentIconSize)
        }

        commentCountLabel.snp.makeConstraints { make in
            make.centerY.equalTo(likeButton)
            make.leading.equalTo(commentIconImageView.snp.trailing).offset(Layout.smallSpacing)
            make.trailing.lessThanOrEqualToSuperview().inset(Layout.horizontalInset)
        }

        titleStackView.snp.makeConstraints { make in
            make.top.equalTo(likeButton.snp.bottom).offset(Layout.sectionSpacing)
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.trailing.lessThanOrEqualToSuperview().inset(Layout.horizontalInset)
        }

        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(titleStackView.snp.bottom).offset(Layout.titleSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(contentLabel.snp.bottom).offset(Layout.titleSpacing)
            make.leading.equalTo(contentLabel)
            make.bottom.equalToSuperview().inset(Layout.verticalInset)
        }
    }

    private func configureView() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = Layout.profileSize / 2
        profileImageView.layer.borderWidth = 1
        profileImageView.layer.borderColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5).cgColor
        profileImageView.backgroundColor = .Feelter.gray100

        authorNameLabel.font = TextStyle.Pretendard.body2
        authorNameLabel.textColor = .Feelter.gray15

        locationLabel.font = TextStyle.Pretendard.caption1
        locationLabel.textColor = .Feelter.gray60

        imageCollectionView.dataSource = self
        imageCollectionView.delegate = self

        pageControl.currentPageIndicatorTintColor = .Feelter.gray0
        pageControl.pageIndicatorTintColor = .Feelter.gray60

        likeButton.setImage(UIImage.Icon.likeEmpty, for: .normal)
        likeButton.setImage(UIImage.Icon.likeFill, for: .selected)
        likeButton.tintColor = .Feelter.gray0
        likeButton.addTarget(self, action: #selector(likeButtonTapped), for: .touchUpInside)

        likeCountLabel.font = TextStyle.Pretendard.caption1
        likeCountLabel.textColor = .Feelter.gray45

        commentIconImageView.image = UIImage(systemName: "message.fill")
        commentIconImageView.tintColor = .Feelter.gray45
        commentIconImageView.contentMode = .scaleAspectFit

        commentCountLabel.font = TextStyle.Pretendard.caption1
        commentCountLabel.textColor = .Feelter.gray45

        titleLabel.font = TextStyle.Mulgyeol.body1
        titleLabel.textColor = .Feelter.gray15
        titleLabel.numberOfLines = 2

        categoryLabel.font = TextStyle.Pretendard.caption1
        categoryLabel.textColor = .Feelter.gray60
        categoryLabel.backgroundColor = UIColor.Feelter.blackTurquoise

        contentLabel.font = TextStyle.Pretendard.body2
        contentLabel.textColor = .Feelter.gray60
        contentLabel.numberOfLines = 0

        timeLabel.font = TextStyle.Pretendard.caption1
        timeLabel.textColor = .Feelter.gray75
    }

    @objc private func likeButtonTapped() {
        guard let postId = currentPostId else { return }
        onLikeTapped?(postId, likeButton.isSelected)
    }
}

extension SearchPostCell: UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        imagePaths.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: SearchPostImageCell.identifier,
            for: indexPath
        ) as? SearchPostImageCell else {
            return UICollectionViewCell()
        }

        let path = imagePaths[indexPath.item]
        cell.configure(with: path)
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / width))
        pageControl.currentPage = min(max(0, page), max(0, pageControl.numberOfPages - 1))
    }
}

private final class SearchPostImageCell: UICollectionViewCell {

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .Feelter.gray90
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }

    func configure(with path: String) {
        imageView.setFeelterImage(with: path)
    }
}
