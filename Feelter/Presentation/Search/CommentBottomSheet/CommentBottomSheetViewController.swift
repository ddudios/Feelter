//
//  CommentBottomSheetViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import UIKit
import SnapKit
import Combine

final class CommentBottomSheetViewController: UIViewController {

    private enum Layout {
        static let handleWidth: CGFloat = 40
        static let handleHeight: CGFloat = 4
        static let handleTopInset: CGFloat = 8
        static let horizontalInset: CGFloat = 16
        static let verticalInset: CGFloat = 12
        static let profileImageSize: CGFloat = 32
        static let profileImageSpacing: CGFloat = 8
        static let inputContainerHeight: CGFloat = 56
        static let inputTextViewMinHeight: CGFloat = 36
        static let inputTextViewMaxHeight: CGFloat = 100
        static let cornerRadius: CGFloat = 20
    }

    var onCommentAdded: (() -> Void)?

    private let postId: String
    private let postUsecase: PostUsecaseProtocol
    private let profileUsecase: ProfileUsecaseProtocol
    private var comments: [Comment] = []
    private var cancellables = Set<AnyCancellable>()

    private let handleView = UIView()
    private let titleLabel = UILabel()
    private let tableView = UITableView()
    private let contentView = UIView()
    private let inputContainerView = UIView()
    private let profileImageView = UIImageView()
    private let inputTextView = UITextView()
    private let placeholderLabel = UILabel()
    private let sendButton = UIButton(type: .system)

    private var inputContainerBottomConstraint: Constraint?

    private var currentUserId: String? {
        return KeychainManager.shared.read(account: "userId")
    }

    init(
        postId: String,
        postUsecase: PostUsecaseProtocol = DIContainer.shared.resolve(PostUsecaseProtocol.self),
        profileUsecase: ProfileUsecaseProtocol = DIContainer.shared.resolve(ProfileUsecaseProtocol.self)
    ) {
        self.postId = postId
        self.postUsecase = postUsecase
        self.profileUsecase = profileUsecase
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        configureLayout()
        configureView()
        setupKeyboardNotifications()
        setupGestures()
        loadComments()
        loadMyProfileImage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureHierarchy() {
        view.addSubview(contentView)
        contentView.addSubview(handleView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(tableView)
        contentView.addSubview(inputContainerView)

        inputContainerView.addSubview(profileImageView)
        inputContainerView.addSubview(inputTextView)
        inputContainerView.addSubview(sendButton)
        inputTextView.addSubview(placeholderLabel)
    }

    private func configureLayout() {
        contentView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.7)
        }

        handleView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Layout.handleTopInset)
            make.centerX.equalToSuperview()
            make.width.equalTo(Layout.handleWidth)
            make.height.equalTo(Layout.handleHeight)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(handleView.snp.bottom).offset(Layout.verticalInset)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        inputContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            inputContainerBottomConstraint = make.bottom.equalToSuperview().constraint
            make.height.greaterThanOrEqualTo(Layout.inputContainerHeight)
        }

        profileImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Layout.horizontalInset)
            make.centerY.equalTo(inputTextView)
            make.size.equalTo(Layout.profileImageSize)
        }

        inputTextView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Layout.verticalInset)
            make.leading.equalTo(profileImageView.snp.trailing).offset(Layout.profileImageSpacing)
            make.trailing.equalTo(sendButton.snp.leading).offset(-8)
            make.height.greaterThanOrEqualTo(Layout.inputTextViewMinHeight)
        }

        placeholderLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }

        sendButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().inset(Layout.verticalInset)
            make.width.height.equalTo(Layout.inputTextViewMinHeight)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.verticalInset)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(inputContainerView.snp.top)
        }
    }

    private func configureView() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0)

        contentView.backgroundColor = .Feelter.gray100
        contentView.layer.cornerRadius = Layout.cornerRadius
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentView.clipsToBounds = true
        contentView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)

        handleView.backgroundColor = .Feelter.gray75
        handleView.layer.cornerRadius = Layout.handleHeight / 2

        titleLabel.text = "댓글"
        titleLabel.font = TextStyle.Pretendard.body2
        titleLabel.textColor = .Feelter.gray15

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 80
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(CommentCell.self, forCellReuseIdentifier: CommentCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive

        inputContainerView.backgroundColor = .Feelter.gray100

        profileImageView.image = UIImage(named: "appIcon")
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = Layout.profileImageSize / 2
        profileImageView.layer.borderWidth = 1
        profileImageView.layer.borderColor = UIColor.Feelter.gray75?.withAlphaComponent(0.5).cgColor
        profileImageView.backgroundColor = .Feelter.gray100

        inputTextView.font = TextStyle.Pretendard.body2
        inputTextView.textColor = .Feelter.gray0
        inputTextView.backgroundColor = .Feelter.blackTurquoise
        inputTextView.layer.cornerRadius = Radius.m
        inputTextView.clipsToBounds = true
        inputTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        inputTextView.textContainer.lineFragmentPadding = 0
        inputTextView.isScrollEnabled = false
        inputTextView.showsVerticalScrollIndicator = false
        inputTextView.delegate = self
        inputTextView.tintColor = .Feelter.gray100

        placeholderLabel.text = "댓글 입력"
        placeholderLabel.font = TextStyle.Pretendard.body2
        placeholderLabel.textColor = .Feelter.gray100
        placeholderLabel.isUserInteractionEnabled = false

        sendButton.setImage(UIImage.Icon.message, for: .normal)
        sendButton.tintColor = .Feelter.brightTurquoise
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        sendButton.isEnabled = false
    }

    private func loadMyProfileImage() {
        Task { [weak self] in
            guard let self else { return }

            do {
                let profile = try await profileUsecase.fetchMyProfile()
                await MainActor.run {
                    if let path = profile.profileImageURL, !path.isEmpty {
                        self.profileImageView.setFeelterImage(with: path)
                    }
                }
            } catch {
                await MainActor.run {
                    self.profileImageView.image = UIImage(named: "appIcon")
                }
            }
        }
    }

    private func loadComments() {
        Task {
            do {
                let postDetail = try await postUsecase.fetchPostDetail(postId: postId)
                await MainActor.run {
                    self.comments = postDetail.comments
                    self.tableView.reloadData()
                    self.updateTitle()
                }
            } catch {
                await MainActor.run {
                    self.showErrorAlert(message: "댓글을 불러오는데 실패했습니다.")
                }
            }
        }
    }

    private func updateTitle() {
        titleLabel.text = "댓글 \(comments.count)"
    }

    @objc private func sendButtonTapped() {
        let content = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        sendButton.isEnabled = false
        inputTextView.isEditable = false

        Task {
            do {
                _ = try await postUsecase.createComment(postId: postId, content: content)
                await MainActor.run {
                    inputTextView.text = ""
                    inputTextView.isEditable = true
                    sendButton.isEnabled = false
                    placeholderLabel.isHidden = false
                    loadComments()
                    onCommentAdded?()
                }
            } catch {
                await MainActor.run {
                    inputTextView.isEditable = true
                    sendButton.isEnabled = true
                    showErrorAlert(message: "댓글 작성에 실패했습니다.")
                }
            }
        }
    }

    private func showCommentActionSheet(for comment: Comment, sourceView: UIView) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "수정", style: .default) { [weak self] _ in
            self?.showEditComment(comment: comment)
        })
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.showDeleteConfirmation(comment: comment)
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))

        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sourceView
            popoverController.sourceRect = sourceView.bounds
            popoverController.permittedArrowDirections = .up
        }

        present(alert, animated: true)
    }

    private func showEditComment(comment: Comment) {
        let alert = UIAlertController(title: "댓글 수정", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = comment.content
            textField.placeholder = "댓글을 입력하세요"
        }

        alert.addAction(UIAlertAction(title: "수정", style: .default) { [weak self] _ in
            guard let self = self,
                  let content = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else {
                return
            }

            Task {
                do {
                    _ = try await self.postUsecase.updateComment(
                        postId: self.postId,
                        commentId: comment.id,
                        content: content
                    )
                    await MainActor.run {
                        self.loadComments()
                        self.onCommentAdded?()
                    }
                } catch {
                    await MainActor.run {
                        self.showErrorAlert(message: "댓글 수정에 실패했습니다.")
                    }
                }
            }
        })

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }

    private func showDeleteConfirmation(comment: Comment) {
        let alert = UIAlertController(
            title: "댓글 삭제",
            message: "이 댓글을 삭제할까요?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            guard let self = self else { return }

            Task {
                do {
                    try await self.postUsecase.deleteComment(postId: self.postId, commentId: comment.id)
                    await MainActor.run {
                        self.loadComments()
                        self.onCommentAdded?()
                    }
                } catch {
                    await MainActor.run {
                        self.showErrorAlert(message: "댓글 삭제에 실패했습니다.")
                    }
                }
            }
        })

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "오류",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        contentView.addGestureRecognizer(panGesture)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        view.addGestureRecognizer(tapGesture)
    }

    private func animateIn() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.contentView.transform = .identity
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        }
    }

    private func animateOut(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.contentView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0)
        } completion: { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                contentView.transform = CGAffineTransform(translationX: 0, y: translation.y)
            }
        case .ended:
            if translation.y > 100 || velocity.y > 500 {
                animateOut()
            } else {
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                    self.contentView.transform = .identity
                }
            }
        default:
            break
        }
    }

    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !contentView.frame.contains(location) {
            animateOut()
        }
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }

        inputContainerBottomConstraint?.update(offset: -keyboardFrame.height)

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }

        inputContainerBottomConstraint?.update(offset: 0)

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension CommentBottomSheetViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: CommentCell.identifier,
            for: indexPath
        ) as? CommentCell else {
            return UITableViewCell()
        }

        let comment = comments[indexPath.row]
        let isOwnedByCurrentUser = comment.writer.id == currentUserId
        cell.configure(with: comment, isOwnedByCurrentUser: isOwnedByCurrentUser)
        cell.onMoreTapped = { [weak self] sourceView in
            self?.showCommentActionSheet(for: comment, sourceView: sourceView)
        }
        return cell
    }
}

// MARK: - UITextViewDelegate
extension CommentBottomSheetViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let content = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        sendButton.isEnabled = !content.isEmpty
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
}
