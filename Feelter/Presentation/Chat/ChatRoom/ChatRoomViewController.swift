//
//  ChatRoomViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import UIKit
import SnapKit
import PhotosUI
import Combine
import UniformTypeIdentifiers

final class ChatRoomViewController: BaseViewController {

    private enum Layout {
        static let inputBarHeight: CGFloat = 56
        static let inputHorizontalInset: CGFloat = 16
        static let inputVerticalInset: CGFloat = 8
        static let inputButtonSize: CGFloat = 28
        static let textViewMinHeight: CGFloat = 36
        static let textViewMaxLines: Int = 7
        static let messageSpacing: CGFloat = 8
        static let messageBottomInset: CGFloat = 8
    }

    private enum Item {
        case date(Date)
        case message(ChatMessageViewItem)
    }

    private let chatRoom: ChatRoom
    private let viewModel: ChatRoomViewModel
    private var cancellables = Set<AnyCancellable>()

    private let messageTableView = UITableView(frame: .zero, style: .plain)
    private let inputContainerView = UIView()
    private let inputStackView = UIStackView()
    private let attachmentButton = UIButton(type: .system)
    private let messageTextView = UITextView()
    private let placeholderLabel = UILabel()
    private let sendButton = UIButton(type: .system)
    private let inputSeparatorView = UIView()

    // 선택된 이미지 미리보기
    private let selectedImagesScrollView = UIScrollView()
    private let selectedImagesStackView = UIStackView()

    private var inputBottomConstraint: Constraint?
    private var selectedImagesHeightConstraint: Constraint?
    private var textViewHeightConstraint: Constraint?
    private var items: [Item] = []
    private var messages: [ChatMessageViewItem] = [] {
        didSet {
            rebuildItems()
        }
    }
    private var pendingImages: [ChatImageSource] = []
    private var didScrollToBottomOnAppear = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter
    }()

    private let calendar = Calendar.current

    // TODO: 사용자 ID 연동 후 내 메시지 판별에 사용
    private var currentUserId: String?

    // Subjects for Input
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let viewWillDisappearSubject = PassthroughSubject<Void, Never>()
    private let sendButtonTappedSubject = PassthroughSubject<Void, Never>()
    private let messageTextSubject = CurrentValueSubject<String, Never>("")
    private let selectedImagesSubject = CurrentValueSubject<[UIImage], Never>([])

    init(chatRoom: ChatRoom, viewModel: ChatRoomViewModel) {
        self.chatRoom = chatRoom
        self.viewModel = viewModel
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

        setupKeyboardDismissGesture()

        setupKeyboardObservers()

        updateSendButtonState()

        rebuildItems()

        // Keychain에서 현재 사용자 ID 가져오기
        currentUserId = KeychainManager.shared.read(account: "userId")

        // ViewModel 바인딩
        bind()

        // 초기 로드 트리거
        viewDidLoadSubject.send()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCustomTabBarHidden(true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didScrollToBottomOnAppear {
            didScrollToBottomOnAppear = true
            messageTableView.layoutIfNeeded()
            scrollToBottom(animated: false)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setCustomTabBarHidden(false)

        // Socket 연결 해제 트리거
        viewWillDisappearSubject.send()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateMessageTableInsets()
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
            make.height.greaterThanOrEqualTo(Layout.inputBarHeight)
        }
    }

    override func configureView() {
        super.configureView()
        title = chatRoom.opponent.nick
        configureNavigationBar()
    }

    private func setupKeyboardDismissGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
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
        inputContainerView.backgroundColor = .clear

        inputSeparatorView.backgroundColor = .Feelter.blackTurquoise
        inputContainerView.addSubview(inputSeparatorView)

        // 선택된 이미지 스크롤뷰 설정
        selectedImagesScrollView.showsHorizontalScrollIndicator = false
        selectedImagesScrollView.backgroundColor = .clear
        selectedImagesScrollView.isHidden = true
        inputContainerView.addSubview(selectedImagesScrollView)

        selectedImagesStackView.axis = .horizontal
        selectedImagesStackView.spacing = 8
        selectedImagesStackView.alignment = .center
        selectedImagesScrollView.addSubview(selectedImagesStackView)

        inputStackView.axis = .horizontal
        inputStackView.spacing = Layout.messageSpacing
        inputStackView.alignment = .bottom  // 버튼들이 하단에 정렬되도록
        inputContainerView.addSubview(inputStackView)

        attachmentButton.tintColor = .Feelter.blackTurquoise
        attachmentButton.setImage(UIImage.Icon.add, for: .normal)
        attachmentButton.addTarget(self, action: #selector(attachmentButtonTapped), for: .touchUpInside)

        // UITextView 설정
        setupMessageTextView()

        sendButton.setImage(UIImage.Icon.message, for: .normal)
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)

        inputStackView.addArrangedSubview(attachmentButton)
        inputStackView.addArrangedSubview(messageTextView)
        inputStackView.addArrangedSubview(sendButton)

        // 제약 설정
        inputSeparatorView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }

        selectedImagesScrollView.snp.makeConstraints { make in
            make.top.equalTo(inputSeparatorView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(Layout.inputHorizontalInset)
            selectedImagesHeightConstraint = make.height.equalTo(0).constraint
        }

        selectedImagesStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }

        inputStackView.snp.makeConstraints { make in
            make.top.equalTo(selectedImagesScrollView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(Layout.inputHorizontalInset)
            make.bottom.equalToSuperview().inset(Layout.inputVerticalInset)
        }

        attachmentButton.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.inputButtonSize)
        }

        sendButton.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.inputButtonSize)
        }

        messageTextView.snp.makeConstraints { make in
            textViewHeightConstraint = make.height.equalTo(Layout.textViewMinHeight).constraint
        }

        // Placeholder를 TextView 위에 배치
        messageTextView.addSubview(placeholderLabel)
        placeholderLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
    }

    /// UITextView 설정 (카카오톡 스타일)
    private func setupMessageTextView() {
        messageTextView.font = TextStyle.Pretendard.body2 ?? .systemFont(ofSize: 14)
        messageTextView.textColor = .Feelter.gray0
        messageTextView.tintColor = .Feelter.gray100
        messageTextView.backgroundColor = .Feelter.blackTurquoise
        messageTextView.layer.cornerRadius = Radius.m
        messageTextView.clipsToBounds = true

        // 텍스트 컨테이너 여백 설정
        messageTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        messageTextView.textContainer.lineFragmentPadding = 0

        // 초기 상태: 스크롤 비활성화 (동적 높이 조절을 위해)
        messageTextView.isScrollEnabled = false
        messageTextView.showsVerticalScrollIndicator = false

        messageTextView.delegate = self

        // Placeholder 설정
        placeholderLabel.text = "메시지 입력"
        placeholderLabel.font = TextStyle.Pretendard.body2 ?? .systemFont(ofSize: 14)
        placeholderLabel.textColor = .Feelter.gray100
        placeholderLabel.isUserInteractionEnabled = false
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

    /// ViewModel과 바인딩
    ///
    /// 역할:
    /// 1. Input 생성 및 ViewModel에 전달
    /// 2. Output 구독 및 UI 업데이트
    ///
    private func bind() {
        // Input 생성
        let input = ChatRoomViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            viewWillDisappear: viewWillDisappearSubject.eraseToAnyPublisher(),
            sendButtonTapped: sendButtonTappedSubject.eraseToAnyPublisher(),
            messageText: messageTextSubject.eraseToAnyPublisher(),
            selectedImages: selectedImagesSubject.eraseToAnyPublisher()
        )
        // Output 구독
        let output = viewModel.transform(input: input)

        // 메시지 목록 업데이트
        output.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chatMessages in
                guard let self = self else { return }
                // Domain Entity -> View Item 변환
                self.messages = self.convertToChatMessageViewItems(chatMessages)

                // items 재구성 (날짜 섹션 포함)
                self.rebuildItems()
            }
            .store(in: &cancellables)

        // 로딩 상태
        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // TODO: 로딩 인디케이터 표시
            }
            .store(in: &cancellables)

        // 전송 중 상태
        output.isSending
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // TODO: 전송 중 인디케이터 표시
            }
            .store(in: &cancellables)

        // 에러 처리
        output.error
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] errorMessage in
                self?.showErrorAlert(message: errorMessage)
            }
            .store(in: &cancellables)

        // 스크롤 트리거
        output.scrollToBottom
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.scrollToBottom(animated: true)
            }
            .store(in: &cancellables)

        // 전송 버튼 활성화 상태
        output.isSendButtonEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                guard let self = self else { return }
                self.sendButton.isEnabled = isEnabled
                self.sendButton.tintColor = isEnabled ? .Feelter.brightTurquoise : .Feelter.blackTurquoise
            }
            .store(in: &cancellables)
    }

    /// ChatMessage (Domain) → ChatMessageViewItem (View) 변환
    ///
    /// 역할:
    /// 1. Domain Entity를 View용 모델로 변환
    /// 2. isOutgoing 판별 (senderId == currentUserId)
    /// 3. files URL을 ChatImageSource.remote로 변환
    ///
    private func convertToChatMessageViewItems(_ chatMessages: [ChatMessage]) -> [ChatMessageViewItem] {
        return chatMessages.map { chatMessage in
            let isOutgoing = chatMessage.senderId == currentUserId

            // files (String 배열) → ChatImageSource 배열 변환
            // 안전하게 변환: 빈 문자열이나 유효하지 않은 URL 필터링
            let images: [ChatImageSource] = chatMessage.files
                .filter { !$0.isEmpty }
                .compactMap { urlString in
                    // URL 유효성 검사
                    guard URL(string: urlString) != nil else { return nil }
                    return .remote(urlString)
                }

            // content가 공백이 아닌 실제 내용이 있을 때만 표시
            let displayText: String?
            if let content = chatMessage.content,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                displayText = content
            } else {
                displayText = nil
            }

            return ChatMessageViewItem(
                id: chatMessage.chatId,
                text: displayText,
                images: images,
                date: chatMessage.createdAt,
                isOutgoing: isOutgoing,
                status: chatMessage.status,
                showsTime: true  // rebuildItems()에서 다시 계산됨
            )
        }
    }

    /// 에러 알럿 표시
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "오류",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
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
        // 텍스트가 필수 (이미지만 보내는 것은 불가)
        let hasText = !messageTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isEnabled = hasText
        sendButton.tintColor = sendButton.isEnabled ? .Feelter.brightTurquoise : .Feelter.blackTurquoise
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

    private func updateMessageTableInsets() {
        let bottomInset = Layout.messageBottomInset
        let newInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        if messageTableView.contentInset != newInsets {
            messageTableView.contentInset = newInsets
            messageTableView.scrollIndicatorInsets = newInsets
        }
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

    @objc override func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func attachmentButtonTapped() {
        let actionSheet = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )

        // 옵션 1: 앨범에서 선택
        let albumAction = UIAlertAction(title: "앨범에서 선택", style: .default) { [weak self] _ in
            self?.openImagePicker()
        }

        // 옵션 2: 파일 선택
        let fileAction = UIAlertAction(title: "파일 선택", style: .default) { [weak self] _ in
            self?.openFilePicker()
        }

        // 취소 버튼
        let cancelAction = UIAlertAction(title: "취소", style: .cancel)

        actionSheet.addAction(albumAction)
        actionSheet.addAction(fileAction)
        actionSheet.addAction(cancelAction)

        // iPad 대응 (popover)
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = attachmentButton
            popover.sourceRect = attachmentButton.bounds
        }

        present(actionSheet, animated: true)
    }

    /// 앨범에서 이미지/비디오 선택 (PHPicker)
    private func openImagePicker() {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 5
        configuration.filter = .any(of: [.images, .videos])

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// 파일 선택 (UIDocumentPicker)
    /// 지원 확장자: pdf, jpg, png, jpeg, gif
    private func openFilePicker() {
        let supportedTypes: [UTType] = [.pdf, .image, .jpeg, .png, .gif]

        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        present(documentPicker, animated: true)
    }

    @objc private func sendButtonTapped() {
        // ViewModel에게 전송 이벤트 전달
        sendButtonTappedSubject.send()

        // UI 초기화
        messageTextView.text = ""
        messageTextSubject.send("")
        placeholderLabel.isHidden = false
        pendingImages.removeAll()
        selectedImagesSubject.send([])
        updateSelectedImagesPreview()
        updateSendButtonState()

        // 높이 초기화
        textViewHeightConstraint?.update(offset: Layout.textViewMinHeight)
        messageTextView.isScrollEnabled = false
        UIView.animate(withDuration: 0.1) {
            self.view.layoutIfNeeded()
        }
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

// MARK: - UITextViewDelegate
extension ChatRoomViewController: UITextViewDelegate {

    /// 텍스트 변경 시 호출 - 동적 높이 조절 및 placeholder 처리
    func textViewDidChange(_ textView: UITextView) {
        // 1. ViewModel에 텍스트 전달
        messageTextSubject.send(textView.text)

        // 2. 전송 버튼 상태 업데이트
        updateSendButtonState()

        // 3. Placeholder 표시/숨김
        placeholderLabel.isHidden = !textView.text.isEmpty

        // 4. 동적 높이 계산 및 스크롤 제어
        updateTextViewHeight(textView)
    }

    /// TextView 높이 계산 및 스크롤 제어
    ///
    /// - 최대 7줄까지 높이 증가
    /// - 7줄 초과 시 스크롤 활성화
    /// - font.lineHeight와 textContainerInset을 사용하여 정확한 높이 계산
    private func updateTextViewHeight(_ textView: UITextView) {
        guard let font = textView.font else { return }

        // 최대 높이 계산: lineHeight * 7줄 + 상하 여백
        let lineHeight = font.lineHeight
        let verticalInsets = textView.textContainerInset.top + textView.textContainerInset.bottom
        let maxHeight = lineHeight * CGFloat(Layout.textViewMaxLines) + verticalInsets

        // 현재 콘텐츠 높이 계산
        let fixedWidth = textView.frame.width - textView.textContainerInset.left - textView.textContainerInset.right
        let sizeThatFits = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        let contentHeight = sizeThatFits.height

        // 최소/최대 높이 범위 내에서 결정
        let newHeight = min(max(contentHeight, Layout.textViewMinHeight), maxHeight)

        // 스크롤 활성화 여부 결정
        let shouldEnableScroll = contentHeight > maxHeight

        // 높이가 변경되었을 때만 업데이트
        if abs(newHeight - (textViewHeightConstraint?.layoutConstraints.first?.constant ?? 0)) > 0.5 {
            textViewHeightConstraint?.update(offset: newHeight)
            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            }
        }

        // 스크롤 상태 변경
        if textView.isScrollEnabled != shouldEnableScroll {
            textView.isScrollEnabled = shouldEnableScroll
            textView.showsVerticalScrollIndicator = shouldEnableScroll
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        // placeholder 위치 조정 (멀티라인일 때 상단 정렬)
        placeholderLabel.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalToSuperview().offset(textView.textContainerInset.top)
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        // 텍스트가 비어있을 때 placeholder를 중앙으로 복귀
        if textView.text.isEmpty {
            placeholderLabel.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(16)
                make.trailing.equalToSuperview().offset(-12)
                make.centerY.equalToSuperview()
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ChatRoomViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view?.isDescendant(of: inputContainerView) ?? false)
    }
}

// MARK: - Selected Images Preview
private extension ChatRoomViewController {

    /// 선택된 이미지 미리보기 UI 업데이트
    ///
    /// 역할:
    /// 1. 기존 썸네일 제거
    /// 2. 선택된 이미지마다 썸네일 컨테이너 생성
    /// 3. x-mark 버튼 추가로 개별 제거 가능
    /// 4. 스크롤뷰 높이 및 표시 여부 조정
    ///
    func updateSelectedImagesPreview() {
        // 1. 기존 썸네일 모두 제거
        selectedImagesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let images = selectedImagesSubject.value

        // 2. 이미지가 없으면 숨김
        if images.isEmpty {
            selectedImagesScrollView.isHidden = true
            selectedImagesHeightConstraint?.update(offset: 0)
            UIView.animate(withDuration: 0.25) {
                self.view.layoutIfNeeded()
            }
            return
        }

        // 3. 이미지가 있으면 썸네일 생성
        for (index, image) in images.enumerated() {
            let thumbnailContainer = createThumbnailView(image: image, index: index)
            selectedImagesStackView.addArrangedSubview(thumbnailContainer)
        }

        // 4. 스크롤뷰 표시 및 높이 조정
        selectedImagesScrollView.isHidden = false
        selectedImagesHeightConstraint?.update(offset: 88) // 80(썸네일) + 8(여백)
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    /// 썸네일 컨테이너 뷰 생성
    ///
    /// 구조:
    /// - 컨테이너 (80x80)
    ///   - UIImageView (꽉 채움, rounded corners)
    ///   - X 버튼 (우상단, 24x24)
    ///
    func createThumbnailView(image: UIImage, index: Int) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        // 이미지 뷰
        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Radius.m
        imageView.backgroundColor = .Feelter.gray100
        containerView.addSubview(imageView)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.height.equalTo(80)
        }

        // X 버튼
        let removeButton = UIButton(type: .system)
        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = .white
        removeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        removeButton.layer.cornerRadius = 12
        removeButton.clipsToBounds = true
        removeButton.tag = index
        removeButton.addTarget(self, action: #selector(removeImageButtonTapped(_:)), for: .touchUpInside)
        containerView.addSubview(removeButton)

        removeButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
            make.width.height.equalTo(24)
        }

        return containerView
    }

    /// X 버튼 탭 시 해당 이미지 제거
    @objc func removeImageButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        var images = selectedImagesSubject.value

        guard index < images.count else { return }

        images.remove(at: index)
        selectedImagesSubject.send(images)

        // pendingImages도 동기화
        pendingImages.remove(at: index)

        updateSelectedImagesPreview()
        updateSendButtonState()
    }
}

// MARK: - PHPickerViewControllerDelegate
extension ChatRoomViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard !results.isEmpty else { return }

        let dispatchGroup = DispatchGroup()
        var loadedImages: [UIImage?] = Array(repeating: nil, count: results.count)

        for (index, result) in results.enumerated() {
            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else { continue }

            dispatchGroup.enter()
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    loadedImages[index] = image
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let images = loadedImages.compactMap { $0 }

            // pendingImages 업데이트 (UI용)
            self.pendingImages = images.map { .local($0) }

            // ViewModel에 UIImage 배열 전달
            self.selectedImagesSubject.send(images)

            // 이미지 미리보기 UI 업데이트
            self.updateSelectedImagesPreview()

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

// MARK: - UIDocumentPickerDelegate
extension ChatRoomViewController: UIDocumentPickerDelegate {

    /// 파일 선택 완료 시 호출
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            // 보안 스코프 접근 시작
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ 파일 접근 권한 획득 실패: \(url)")
                continue
            }

            defer {
                // 보안 스코프 접근 종료
                url.stopAccessingSecurityScopedResource()
            }

            // 파일 정보 로그 출력
            let fileName = url.lastPathComponent
            let fileExtension = url.pathExtension.lowercased()

            print("📎 선택된 파일:")
            print("   - 파일명: \(fileName)")
            print("   - 확장자: \(fileExtension)")
            print("   - URL: \(url.absoluteString)")

            // TODO: 추후 전송 로직 연결
            // 파일을 임시 디렉토리로 복사하거나 업로드 처리
        }
    }

    /// 파일 선택 취소 시 호출
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("📎 파일 선택 취소됨")
    }
}
