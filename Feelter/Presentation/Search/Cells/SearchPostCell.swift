//
//  SearchPostCell.swift
//  Feelter
//
//  Created by Suji Jang on 1/21/26.
//

import UIKit
import SnapKit
import AVFoundation

final class SearchPostCell: UITableViewCell {

    var onLikeTapped: ((String, Bool) -> Void)?
    var onMoreTapped: ((String, UIView) -> Void)?
    var onCommentTapped: ((String) -> Void)?
    var onImageTapped: (([String], Int) -> Void)?

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let verticalInset: CGFloat = 16
        static let profileSize: CGFloat = 36
        static let imageHeight: CGFloat = 320
        static let iconSize: CGFloat = 22
        static let commentIconSize: CGFloat = 18
        static let titleSpacing: CGFloat = 8
        static let smallSpacing: CGFloat = 2
        static let sectionSpacing: CGFloat = 12
        static let moreButtonSize: CGFloat = 24
        static let moreButtonTrailingInset: CGFloat = 20
    }

    private let profileImageView = UIImageView()
    private let authorNameLabel = UILabel()
    private let locationLabel = UILabel()
    private let moreButton = UIButton(type: .system)

    private let imageCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.register(SearchPostImageCell.self, forCellWithReuseIdentifier: SearchPostImageCell.identifier)
        return collectionView
    }()

    private let pageControl = UIPageControl()

    private let likeButton = UIButton(type: .custom)
    private let likeCountLabel = UILabel()
    private let commentButton = UIButton(type: .custom)
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
            let width = imageCollectionView.bounds.width
            let height = imageCollectionView.bounds.height
            guard width > 0, height > 0 else { return }
            let size = CGSize(width: width, height: height)
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
        moreButton.isHidden = true
        onMoreTapped = nil
        onLikeTapped = nil
        onCommentTapped = nil
        pageControl.currentPage = 0
        pageControl.numberOfPages = 0
        imageCollectionView.setContentOffset(.zero, animated: false)
        imageCollectionView.reloadData()
    }

    func configure(with item: SearchPostItem, isOwnedByCurrentUser: Bool) {
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
        contentLabel.numberOfLines = 0
        timeLabel.text = item.timeText
        moreButton.isHidden = !isOwnedByCurrentUser
        moreButton.isUserInteractionEnabled = isOwnedByCurrentUser

        pageControl.numberOfPages = imagePaths.count
        pageControl.isHidden = imagePaths.isEmpty
        pageControl.currentPage = 0
        imageCollectionView.reloadData()
    }

    private func configureHierarchy() {
        contentView.addSubview(profileImageView)
        contentView.addSubview(authorNameLabel)
        contentView.addSubview(locationLabel)
        contentView.addSubview(moreButton)
        contentView.addSubview(imageCollectionView)
        contentView.addSubview(pageControl)
        contentView.addSubview(likeButton)
        contentView.addSubview(likeCountLabel)
        contentView.addSubview(commentButton)
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

        moreButton.snp.makeConstraints { make in
            make.centerY.equalTo(profileImageView)
            make.trailing.equalToSuperview().inset(Layout.moreButtonTrailingInset)
            make.size.equalTo(Layout.moreButtonSize)
        }

        authorNameLabel.snp.makeConstraints { make in
            make.top.equalTo(profileImageView.snp.top)
            make.leading.equalTo(profileImageView.snp.trailing).offset(Layout.sectionSpacing)
            make.trailing.lessThanOrEqualTo(moreButton.snp.leading).offset(-Layout.sectionSpacing)
        }

        locationLabel.snp.makeConstraints { make in
            make.top.equalTo(authorNameLabel.snp.bottom).offset(4)
            make.leading.equalTo(authorNameLabel)
            make.trailing.lessThanOrEqualTo(moreButton.snp.leading).offset(-Layout.sectionSpacing)
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
            make.top.equalTo(pageControl.snp.bottom)
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.size.equalTo(Layout.iconSize)
        }

        likeCountLabel.snp.makeConstraints { make in
            make.centerY.equalTo(likeButton)
            make.leading.equalTo(likeButton.snp.trailing).offset(Layout.smallSpacing)
        }

        commentButton.snp.makeConstraints { make in
            make.centerY.equalTo(likeButton)
            make.leading.equalTo(likeCountLabel.snp.trailing).offset(Layout.sectionSpacing)
            make.size.equalTo(Layout.commentIconSize)
        }

        commentCountLabel.snp.makeConstraints { make in
            make.centerY.equalTo(likeButton)
            make.leading.equalTo(commentButton.snp.trailing).offset(Layout.smallSpacing)
            make.trailing.lessThanOrEqualToSuperview().inset(Layout.horizontalInset)
        }

        titleStackView.snp.makeConstraints { make in
            make.top.equalTo(likeButton.snp.bottom).offset(6)
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.trailing.lessThanOrEqualToSuperview().inset(Layout.horizontalInset)
        }

        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(titleStackView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(contentLabel.snp.bottom).offset(2)
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

        moreButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreButton.tintColor = .Feelter.gray45
        moreButton.isHidden = true
        moreButton.addTarget(self, action: #selector(moreButtonTapped), for: .touchUpInside)

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

        commentButton.setImage(UIImage(systemName: "message.fill"), for: .normal)
        commentButton.tintColor = .Feelter.gray45
        commentButton.addTarget(self, action: #selector(commentButtonTapped), for: .touchUpInside)

        commentCountLabel.font = TextStyle.Pretendard.caption1
        commentCountLabel.textColor = .Feelter.gray45

        titleLabel.font = TextStyle.Pretendard.body1
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

    @objc private func moreButtonTapped() {
        guard let postId = currentPostId else { return }
        onMoreTapped?(postId, moreButton)
    }

    @objc private func commentButtonTapped() {
        guard let postId = currentPostId else { return }
        onCommentTapped?(postId)
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

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onImageTapped?(imagePaths, indexPath.item)
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
    private var currentConfigureId = UUID()
    private let playIconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .Feelter.gray90

        // 재생 아이콘 추가
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        playIconView.image = UIImage(systemName: "play.fill", withConfiguration: config)
        playIconView.tintColor = .white
        playIconView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        playIconView.layer.cornerRadius = 30
        playIconView.clipsToBounds = true
        playIconView.isHidden = true
        contentView.addSubview(playIconView)
        playIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(60)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentConfigureId = UUID()
        imageView.image = nil
        playIconView.isHidden = true
    }

    func configure(with path: String) {
        currentConfigureId = UUID()
        let configureId = currentConfigureId
        // 파일 확장자로 동영상 여부 확인
        let fileExtension = (path as NSString).pathExtension.lowercased()
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "m4v"]

        if videoExtensions.contains(fileExtension) {
            // 동영상: 첫 프레임 썸네일 표시
            imageView.isHidden = false
            imageView.image = UIImage(systemName: "video.fill")
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = .Feelter.gray60
            playIconView.isHidden = false

            loadVideoThumbnail(path: path, configureId: configureId) { [weak self] thumbnail in
                guard let self = self else { return }
                guard configureId == self.currentConfigureId else { return }
                if let thumbnail = thumbnail {
                    self.imageView.image = thumbnail
                    self.imageView.contentMode = .scaleAspectFill
                }
            }
        } else {
            // 이미지
            imageView.isHidden = false
            playIconView.isHidden = true
            imageView.contentMode = .scaleAspectFill
            imageView.setFeelterImage(with: path)
        }
    }

    private func loadVideoThumbnail(path: String, configureId: UUID, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let videoURL = self.normalizedRemoteURL(from: path) else {
                completion(nil)
                return
            }

            let asset = AVAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0, preferredTimescale: 600)

            if let imageRef = try? generator.copyCGImage(at: time, actualTime: nil) {
                completion(UIImage(cgImage: imageRef))
            } else {
                completion(nil)
            }
        }
    }

    private func normalizedRemoteURL(from path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            if url.path.hasPrefix("/data/") {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.path = "/v1" + url.path
                return components?.url
            }
            return url
        }

        let baseURLString = Config.baseURL.absoluteString
        let cleanedBase = baseURLString.hasSuffix("/") ? String(baseURLString.dropLast()) : baseURLString

        var urlPath = path
        if urlPath.hasPrefix("/data/") {
            urlPath = "/v1" + urlPath
        } else if urlPath.hasPrefix("/v1/") {
            // 그대로 사용
        } else if urlPath.hasPrefix("/") {
            urlPath = "/v1" + urlPath
        } else {
            urlPath = "/v1/" + urlPath
        }

        return URL(string: cleanedBase + urlPath)
    }
}
