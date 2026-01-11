//
//  ChatRoomViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import UIKit
import SnapKit
import PhotosUI

final class ChatRoomViewController: BaseViewController {

    private enum Layout {
        static let inputBarHeight: CGFloat = 56
        static let inputHorizontalInset: CGFloat = 16
        static let inputVerticalInset: CGFloat = 8
        static let inputButtonSize: CGFloat = 32
        static let textFieldHeight: CGFloat = 40
        static let messageSpacing: CGFloat = 8
    }

    private enum Item {
        case date(Date)
        case message(ChatMessageViewItem)
    }

    private let chatRoom: ChatRoom

    private let messageTableView = UITableView(frame: .zero, style: .plain)
    private let inputContainerView = UIView()
    private let inputStackView = UIStackView()
    private let attachmentButton = UIButton(type: .system)
    private let messageTextField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let inputSeparatorView = UIView()

    private var inputBottomConstraint: Constraint?
    private var items: [Item] = []
    private var messages: [ChatMessageViewItem] = [] {
        didSet {
            rebuildItems()
        }
    }
    private var pendingImages: [ChatImageSource] = []

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter
    }()

    private let calendar = Calendar.current

    // TODO: 사용자 ID 연동 후 내 메시지 판별에 사용
    private var currentUserId: String?

    init(chatRoom: ChatRoom) {
        self.chatRoom = chatRoom
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupInputBar()
        setupKeyboardObservers()
        updateSendButtonState()
        rebuildItems()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCustomTabBarHidden(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setCustomTabBarHidden(false)
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(messageTableView)
        view.addSubview(inputContainerView)
    }

    override func configureLayout() {
        super.configureLayout()

        messageTableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(inputContainerView.snp.top)
        }

        inputContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            inputBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide).constraint
            make.height.equalTo(Layout.inputBarHeight)
        }

        inputSeparatorView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }

        inputStackView.snp.makeConstraints { make in
            make.top.equalTo(inputSeparatorView.snp.bottom).offset(Layout.inputVerticalInset)
            make.leading.trailing.equalToSuperview().inset(Layout.inputHorizontalInset)
            make.bottom.equalToSuperview().inset(Layout.inputVerticalInset)
        }

        attachmentButton.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.inputButtonSize)
        }

        sendButton.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.inputButtonSize)
        }

        messageTextField.snp.makeConstraints { make in
            make.height.equalTo(Layout.textFieldHeight)
        }
    }

    override func configureView() {
        super.configureView()
        title = chatRoom.opponent.nick
        configureNavigationBar()
    }

    private func setupTableView() {
        messageTableView.backgroundColor = .clear
        messageTableView.separatorStyle = .none
        messageTableView.showsVerticalScrollIndicator = false
        messageTableView.keyboardDismissMode = .interactive
        messageTableView.estimatedRowHeight = 80
        messageTableView.rowHeight = UITableView.automaticDimension
        messageTableView.dataSource = self
        messageTableView.delegate = self
        messageTableView.register(ChatMessageCell.self, forCellReuseIdentifier: ChatMessageCell.identifier)
        messageTableView.register(ChatDateSeparatorCell.self, forCellReuseIdentifier: ChatDateSeparatorCell.identifier)
    }

    private func setupInputBar() {
        inputContainerView.backgroundColor = .Feelter.gray100

        inputSeparatorView.backgroundColor = .Feelter.gray90
        inputContainerView.addSubview(inputSeparatorView)

        inputStackView.axis = .horizontal
        inputStackView.spacing = Layout.messageSpacing
        inputStackView.alignment = .center
        inputContainerView.addSubview(inputStackView)

        attachmentButton.tintColor = .Feelter.gray60
        attachmentButton.setImage(UIImage.Icon.add, for: .normal)
        attachmentButton.addTarget(self, action: #selector(attachmentButtonTapped), for: .touchUpInside)

        messageTextField.font = TextStyle.Pretendard.body2
        messageTextField.textColor = .Feelter.gray0
        messageTextField.backgroundColor = .Feelter.deepTurquoise
        messageTextField.layer.cornerRadius = Radius.m
        messageTextField.attributedPlaceholder = NSAttributedString(
            string: "메시지 입력",
            attributes: [.foregroundColor: UIColor.Feelter.gray75 ?? .gray]
        )
        messageTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        messageTextField.leftViewMode = .always
        messageTextField.returnKeyType = .send
        messageTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        messageTextField.delegate = self

        sendButton.tintColor = .Feelter.gray75
        sendButton.setImage(UIImage.Icon.message, for: .normal)
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)

        inputStackView.addArrangedSubview(attachmentButton)
        inputStackView.addArrangedSubview(messageTextField)
        inputStackView.addArrangedSubview(sendButton)
    }

    private func configureNavigationBar() {
        let searchButton = UIBarButtonItem(
            image: UIImage.TabBar.searchEmpty,
            style: .plain,
            target: self,
            action: #selector(searchButtonTapped)
        )
        let moreButton = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal"),
            style: .plain,
            target: self,
            action: #selector(moreButtonTapped)
        )
        navigationItem.rightBarButtonItems = [moreButton, searchButton]
    }

    private func rebuildItems() {
        items = buildItems(from: messages)
        messageTableView.reloadData()
        scrollToBottom(animated: false)
    }

    private func buildItems(from messages: [ChatMessageViewItem]) -> [Item] {
        guard !messages.isEmpty else {
            return [.date(Date())]
        }

        let sortedMessages = messages.sorted { $0.date < $1.date }
        var result: [Item] = []
        var lastDateComponents: DateComponents?

        for index in sortedMessages.indices {
            let message = sortedMessages[index]
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: message.date)
            if dateComponents != lastDateComponents {
                result.append(.date(message.date))
                lastDateComponents = dateComponents
            }

            var updatedMessage = message
            if index < sortedMessages.count - 1 {
                let nextMessage = sortedMessages[index + 1]
                let isSameMinute = calendar.isDate(
                    message.date,
                    equalTo: nextMessage.date,
                    toGranularity: .minute
                )
                updatedMessage.showsTime = !isSameMinute
            } else {
                updatedMessage.showsTime = true
            }

            result.append(.message(updatedMessage))
        }

        return result
    }

    private func updateSendButtonState() {
        let hasText = !(messageTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImages = !pendingImages.isEmpty
        sendButton.isEnabled = hasText || hasImages
        sendButton.tintColor = sendButton.isEnabled ? .Feelter.gray30 : .Feelter.gray75
    }

    private func scrollToBottom(animated: Bool) {
        guard !items.isEmpty else { return }
        let indexPath = IndexPath(row: items.count - 1, section: 0)
        messageTableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }

    private func setCustomTabBarHidden(_ hidden: Bool) {
        (tabBarController as? CustomTabBarController)?.setCustomTabBarHidden(hidden, animated: false)
    }

    private func setupKeyboardObservers() {
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

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardHeight = frame.height - view.safeAreaInsets.bottom
        inputBottomConstraint?.update(offset: -keyboardHeight)

        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }

        scrollToBottom(animated: true)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        inputBottomConstraint?.update(offset: 0)
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func textFieldDidChange() {
        updateSendButtonState()
    }

    @objc private func attachmentButtonTapped() {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 5
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func sendButtonTapped() {
        let trimmedText = (messageTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !trimmedText.isEmpty
        let hasImages = !pendingImages.isEmpty

        guard hasText || hasImages else { return }

        let newMessage = ChatMessageViewItem(
            id: UUID().uuidString,
            text: hasText ? trimmedText : nil,
            images: pendingImages,
            date: Date(),
            isOutgoing: true,
            status: .sending,
            showsTime: true
        )

        messages.append(newMessage)
        messageTextField.text = nil
        pendingImages.removeAll()
        updateSendButtonState()
        scrollToBottom(animated: true)
        // TODO: 메시지 전송 로직과 상태 업데이트 연결
    }

    @objc private func searchButtonTapped() {
        // TODO: 채팅 메시지 검색 연결
    }

    @objc private func moreButtonTapped() {
        // TODO: 더보기 액션 연결
    }
}

// MARK: - UITableViewDataSource
extension ChatRoomViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let item = items[indexPath.row]

        switch item {
        case .date(let date):
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: ChatDateSeparatorCell.identifier,
                for: indexPath
            ) as? ChatDateSeparatorCell else {
                return UITableViewCell()
            }
            cell.configure(with: dateFormatter.string(from: date))
            return cell

        case .message(let message):
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: ChatMessageCell.identifier,
                for: indexPath
            ) as? ChatMessageCell else {
                return UITableViewCell()
            }
            cell.configure(with: message, opponentProfileImagePath: chatRoom.opponent.profileImage)
            cell.onRetryTapped = { [weak self] in
                self?.retryMessage(id: message.id)
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension ChatRoomViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension ChatRoomViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendButtonTapped()
        return true
    }
}

// MARK: - PHPickerViewControllerDelegate
extension ChatRoomViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard !results.isEmpty else { return }

        let dispatchGroup = DispatchGroup()
        var loadedImages: [ChatImageSource?] = Array(repeating: nil, count: results.count)

        for (index, result) in results.enumerated() {
            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else { continue }

            dispatchGroup.enter()
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    loadedImages[index] = .local(image)
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.pendingImages = loadedImages.compactMap { $0 }
            self.updateSendButtonState()
        }
    }
}

// MARK: - Message Actions
private extension ChatRoomViewController {
    func retryMessage(id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].status = .sending
        // TODO: 재전송 로직 연결
    }
}
