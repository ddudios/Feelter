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
import QuickLook
import AVKit
import AVFoundation

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

    /// Chat 화면 전환을 담당하는 Coordinator
    private var chatCoordinator: ChatCoordinator?

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
    private var pendingVideos: [(url: URL, thumbnail: UIImage?)] = []
    private var didScrollToBottomOnAppear = false
    private var needsInitialScrollOnAppear = false
    private var shouldScrollToBottomAfterNextReload = false
    private var isTextViewBeingEdited = false  // TextView 편집 중 플래그
    private var previousMessageCount = 0  // 이전 메시지 개수 (새 메시지 감지용)

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter
    }()

    private let calendar = Calendar.current

    // TODO: 사용자 ID 연동 후 내 메시지 판별에 사용
    private var currentUserId: String?

    /// Quick Look에서 표시할 파일의 로컬 URL
    private var currentPreviewItem: URL?

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

    /// 현재 채팅방 ID 반환 (푸시 알림 필터링용)
    public func getCurrentChatRoomId() -> String {
        return chatRoom.roomId
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // BaseViewController의 키보드 dismiss 제스처를 그대로 사용
        // (override한 gestureRecognizer(_:shouldReceive:) 메서드로 세밀하게 제어)

        setupTableView()

        setupInputBar()

        setupKeyboardObservers()
        setupAppLifecycleObservers()

        updateSendButtonState()

        rebuildItems()

        // Keychain에서 현재 사용자 ID 가져오기
        currentUserId = KeychainManager.shared.read(account: "userId")

        // ChatCoordinator 초기화
        if let navigationController = navigationController {
            chatCoordinator = ChatCoordinator(
                navigationController: navigationController,
                chatRoomViewController: self
            )
        }

        // ViewModel 바인딩
        bind()

        // 초기 로드 트리거
        viewDidLoadSubject.send()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCustomTabBarHidden(true)
        didScrollToBottomOnAppear = false
        needsInitialScrollOnAppear = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 채팅방 최초 진입 시 스크롤을 가장 아래로 (animation 없이)
        scrollToBottomIfNeeded()

        // 채팅방 입장 시 읽음 처리
        markChatRoomAsRead()
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
        scrollToBottomIfNeeded()
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
        messageTableView.register(ChatFileMessageCell.self, forCellReuseIdentifier: ChatFileMessageCell.identifier)
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
        inputStackView.alignment = .center
        inputContainerView.addSubview(inputStackView)

        attachmentButton.tintColor = .Feelter.brightTurquoise
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
            make.leading.equalToSuperview().offset(8)
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
        //TODO: 추후 구현
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
//        navigationItem.rightBarButtonItems = [moreButton, searchButton]
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

                // 새 메시지가 추가되었고, 스크롤뷰가 최하단 근처에 있으면 자동 스크롤
                if chatMessages.count > self.previousMessageCount && self.isNearBottom() {
                    self.shouldScrollToBottomAfterNextReload = true
                }

                self.previousMessageCount = chatMessages.count

                // Domain Entity -> View Item 변환
                self.messages = self.convertToChatMessageViewItems(chatMessages)
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
                self?.shouldScrollToBottomAfterNextReload = true
                self?.scrollToBottom(animated: false)
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
    /// 3. files URL을 이미지 또는 파일 첨부로 분류
    ///
    /// 중요:
    /// - 서버가 PDF를 .jpg 확장자로 저장하는 경우가 있어서
    ///   content(원본 파일명)의 확장자도 함께 확인합니다.
    ///
    private func convertToChatMessageViewItems(_ chatMessages: [ChatMessage]) -> [ChatMessageViewItem] {
        return chatMessages.map { chatMessage in
            let isOutgoing = chatMessage.senderId == currentUserId

            // files를 이미지와 일반 파일로 분류
            var images: [ChatImageSource] = []
            var files: [ChatFileAttachment] = []

            // content에서 원본 파일명 확장자 추출 (파일 전송 시 content = 원본 파일명)
            // 예: content가 "document.pdf"면 원본 확장자는 "pdf"
            let contentExt = (chatMessage.content as NSString?)?.pathExtension.lowercased() ?? ""
            let isPDFByContent = contentExt == "pdf"

            for fileUrl in chatMessage.files where !fileUrl.isEmpty {
                let urlFileName = (fileUrl as NSString).lastPathComponent
                let urlExt = (urlFileName as NSString).pathExtension.lowercased()

                // 이미지 확장자 판별
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic"]

                // 비디오/오디오 확장자 판별
                let videoExtensions = ["mp4", "mov", "m4a", "mp3"]
                let isVideoByContent = videoExtensions.contains(contentExt)

                // PDF 판별: URL 확장자가 pdf이거나, content가 .pdf로 끝나는 경우
                let isPDF = urlExt == "pdf" || isPDFByContent

                if isPDF {
                    // 원본 파일명 사용 (content에서 가져옴, 없으면 URL에서 추출)
                    let displayFileName = chatMessage.content ?? urlFileName
                    files.append(ChatFileAttachment(
                        fileName: displayFileName,
                        fileURL: fileUrl,
                        mimeType: "application/pdf"
                    ))
                } else if videoExtensions.contains(urlExt) || isVideoByContent {
                    // 비디오 파일은 썸네일과 함께 표시
                    images.append(.video(thumbnailImage: nil, videoURL: fileUrl, isLocal: false))
                } else if imageExtensions.contains(urlExt) {
                    images.append(.remote(fileUrl))
                } else {
                    // 기타 파일
                    let displayFileName = chatMessage.content ?? urlFileName
                    let mimeType = ChatFileAttachment.mimeType(for: displayFileName)
                    files.append(ChatFileAttachment(
                        fileName: displayFileName,
                        fileURL: fileUrl,
                        mimeType: mimeType
                    ))
                }
            }

            // 파일 첨부 메시지인 경우 content는 표시하지 않음 (파일명만 표시)
            // 일반 텍스트 메시지인 경우에만 content 표시
            let displayText: String?
            let hasAttachments = !files.isEmpty || !images.isEmpty
            let hasContent = !(chatMessage.content ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            let attachmentExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "pdf", "mp4", "mov", "m4a", "mp3"]
            let isAttachmentFileName = hasAttachments && attachmentExtensions.contains(contentExt)

            if !files.isEmpty || isAttachmentFileName {
                // 파일 메시지: content는 파일명이므로 별도 텍스트로 표시하지 않음
                displayText = nil
            } else if let content = chatMessage.content, hasContent {
                displayText = content
            } else {
                displayText = nil
            }

            return ChatMessageViewItem(
                id: chatMessage.chatId,
                text: displayText,
                images: images,
                files: files,
                date: chatMessage.createdAt,
                isOutgoing: isOutgoing,
                status: chatMessage.status,
                showsTime: true,  // rebuildItems()에서 다시 계산됨
                showsProfile: true  // rebuildItems()에서 다시 계산됨
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
        let oldItemsCount = items.count
        items = buildItems(from: messages)

        // ✅ TableView 업데이트 (reloadData만 사용 - 행 개수 변경 시)
        // beginUpdates/endUpdates는 이미지 로딩 완료 시에만 사용 (셀 높이 재계산용)
        // performWithoutAnimation으로 레이아웃 깜빡임 방지
        UIView.performWithoutAnimation {
            messageTableView.reloadData()
            // 레이아웃 강제 완료 (찌그러짐 방지)
            messageTableView.layoutIfNeeded()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.shouldScrollToBottomAfterNextReload {
                self.scrollToBottom(animated: false)
                self.shouldScrollToBottomAfterNextReload = false
                return
            }
            self.scrollToBottomIfNeeded()
        }
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

            // 이전 메시지 체크
            let previousMessage = index > 0 ? sortedMessages[index - 1] : nil
            let isPreviousFailed = previousMessage?.status == .failed

            // showsTime 계산
            if index < sortedMessages.count - 1 {
                let nextMessage = sortedMessages[index + 1]
                let isSameMinute = calendar.isDate(
                    message.date,
                    equalTo: nextMessage.date,
                    toGranularity: .minute
                )

                // 다음 메시지가 failed이거나 이전 메시지가 failed이면 시간 표시
                if nextMessage.status == .failed || isPreviousFailed {
                    updatedMessage.showsTime = true
                } else {
                    updatedMessage.showsTime = !isSameMinute
                }
            } else {
                updatedMessage.showsTime = true
            }

            // showsProfile 계산 (상대방 메시지만 해당)
            if !message.isOutgoing {
                // 상대방 메시지
                if let prev = previousMessage, !prev.isOutgoing {
                    // 이전 메시지도 상대방 메시지 → 프로필 숨김
                    updatedMessage.showsProfile = false
                } else {
                    // 이전 메시지가 없거나 내 메시지 → 프로필 표시
                    updatedMessage.showsProfile = true
                }
            } else {
                // 내 메시지는 항상 프로필 숨김
                updatedMessage.showsProfile = false
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

    private func scrollToBottomIfNeeded() {
        guard needsInitialScrollOnAppear, !didScrollToBottomOnAppear, !messages.isEmpty, view.window != nil else { return }
        messageTableView.layoutIfNeeded()
        scrollToBottom(animated: false)
        didScrollToBottomOnAppear = true
        needsInitialScrollOnAppear = false
    }

    /// 스크롤뷰가 최하단 근처에 있는지 확인
    ///
    /// 새 메시지 수신 시 자동 스크롤 여부를 판단하기 위해 사용됩니다.
    /// 사용자가 이전 메시지를 보고 있을 때는 자동 스크롤하지 않습니다.
    ///
    /// - Returns: 최하단 100pt 이내면 true
    private func isNearBottom() -> Bool {
        let scrollView = messageTableView
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let contentOffsetY = scrollView.contentOffset.y
        let bottomInset = scrollView.contentInset.bottom

        // 하단 100pt 이내면 "최하단 근처"로 간주
        let threshold: CGFloat = 100
        return contentOffsetY + scrollViewHeight + bottomInset >= contentHeight - threshold
    }

    /// 푸시 알림으로 진입 시 스크롤을 최하단으로 이동 (애니메이션 없음)
    ///
    /// ProfileCoordinator에서 푸시 알림을 통해 채팅방으로 이동할 때 호출됩니다.
    /// 일반적인 조건 체크 없이 강제로 스크롤을 최하단으로 이동합니다.
    public func scrollToBottomForPushNavigation() {
        // 레이아웃 강제 완료
        messageTableView.layoutIfNeeded()

        // items가 비어있지 않으면 스크롤
        guard !items.isEmpty else {
            return
        }

        // 애니메이션 없이 최하단으로 스크롤
        scrollToBottom(animated: false)
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

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// 앱이 활성화될 때 호출 (백그라운드에서 복귀)
    @objc private func appDidBecomeActive() {
        markChatRoomAsRead()
    }

    /// 채팅방을 읽음으로 표시
    /// - viewDidAppear: 채팅방 진입 시
    /// - appDidBecomeActive: 백그라운드에서 복귀 시
    private func markChatRoomAsRead() {
        viewModel.markChatRoomAsRead()
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

        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
            ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)

        let shouldScrollToBottom = !isTextViewBeingEdited && !items.isEmpty
        let targetOffsetY: CGFloat
        if shouldScrollToBottom {
            let finalHeight = max(0, messageTableView.bounds.height - keyboardHeight)
            let topInset = messageTableView.adjustedContentInset.top
            let bottomInset = messageTableView.adjustedContentInset.bottom
            let contentHeight = messageTableView.contentSize.height
            let rawOffset = contentHeight - finalHeight + bottomInset
            targetOffsetY = max(-topInset, rawOffset)
        } else {
            targetOffsetY = messageTableView.contentOffset.y
        }

        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.view.layoutIfNeeded()
            if shouldScrollToBottom {
                self.messageTableView.contentOffset = CGPoint(x: 0, y: targetOffsetY)
            }
        }

        // TextView를 탭해서 키보드가 나타난 경우에는 스크롤하지 않음
        // 메시지 전송 후나 새 메시지 수신 시에는 ViewModel의 scrollToBottom publisher를 통해 스크롤됨
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

    // MARK: - UIGestureRecognizerDelegate Override
    /// BaseViewController의 제스처 delegate 메서드를 override
    /// 세밀한 터치 감지:
    /// - inputContainerView: 키보드 유지
    /// - 메시지 버블 (PDF, 이미지, 텍스트): 키보드 유지 (버블의 탭 제스처 우선)
    /// - 그 외 배경: 키보드 내림
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {

        // 1. inputContainerView 하위 뷰 터치는 키보드 dismiss 안함
        if touch.view?.isDescendant(of: inputContainerView) == true {
            return false
        }

        // 2. messageTableView 내부에서 세밀한 판단
        if touch.view?.isDescendant(of: messageTableView) == true {

            // 터치된 뷰가 상호작용 가능한 요소인지 확인
            if let touchedView = touch.view {
                // UITextView (메시지 버블) - 복사 및 선택 가능하도록 키보드 유지
                if touchedView is UITextView {
                    return false
                }

                // 버블 컨테이너나 상호작용 가능한 뷰인지 확인
                // UIImageView, UILabel (버블 내부), UIButton 등은 키보드 유지
                if touchedView is UIImageView {
                    return false
                }

                if touchedView is UILabel && touchedView.superview?.superview is ChatMessageCell {
                    return false
                }

                if touchedView is UIView && touchedView.superview is ChatImageGridView {
                    return false
                }

                if touchedView is UIButton {
                    return false
                }

                // UITableViewCell이나 그 contentView는 빈 공간으로 간주 → 키보드 내림
                if touchedView is UITableViewCell {
                    return true
                }

                // 그 외 테이블뷰의 배경 뷰도 키보드 내림
                if touchedView == messageTableView {
                    return true
                }

                // ChatImageGridView 내부의 이미지 컨테이너 확인
                // gestureRecognizers가 있고 tag가 설정된 UIView는 이미지 컨테이너
                if touchedView is UIView,
                   !(touchedView is UIStackView),
                   !(touchedView is UITableViewCell),
                   let gestureRecognizers = touchedView.gestureRecognizers,
                   !gestureRecognizers.isEmpty {
                    return false
                }

                // 명시적으로 판단하지 못한 경우: 클래스 이름으로 확인
                let className = String(describing: type(of: touchedView))

                // contentView 확인 (클래스 이름으로)
                if className.contains("ContentView") {
                    return true
                }

                // 버블 관련 뷰들은 키보드 유지
                if className.contains("Bubble") || className.contains("Message") || className.contains("File") {
                    return false
                }
            }

            // 기본값: 테이블뷰 내부의 명확하지 않은 터치는 키보드 내림
            return true
        }

        // 3. 그 외 배경 터치는 키보드 내림
        return true
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

    /// 앨범에서 이미지/동영상 선택 (PHPicker)
    /// 지원: 이미지, 동영상 (mp4, mov, m4a - 최대 50MB)
    private func openImagePicker() {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 5
        configuration.filter = .any(of: [.images, .videos])  // ✅ 이미지 + 동영상

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// 파일 선택 (UIDocumentPicker)
    /// 지원 확장자: 모든 파일
    private func openFilePicker() {
        let supportedTypes: [UTType] = [.item]

        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        present(documentPicker, animated: true)
    }

    @objc private func sendButtonTapped() {
        // 높이 초기화를 먼저 수행 (애니메이션 없이)
        textViewHeightConstraint?.update(offset: Layout.textViewMinHeight)
        messageTextView.isScrollEnabled = false

        // 동영상이 있으면 먼저 전송
        if !pendingVideos.isEmpty {
            uploadAndSendVideos()
        }

        // ViewModel에게 전송 이벤트 전달 (텍스트 + 이미지)
        sendButtonTappedSubject.send()

        // UI 초기화 (애니메이션 없이 즉시 처리)
        UIView.performWithoutAnimation {
            messageTextView.text = ""
            messageTextSubject.send("")
            placeholderLabel.isHidden = false
            pendingImages.removeAll()
            pendingVideos.removeAll()
            selectedImagesSubject.send([])
            updateSelectedImagesPreview()
            updateSendButtonState()

            // 레이아웃 즉시 완료
            self.view.layoutIfNeeded()
        }

        // 스크롤은 메시지가 추가된 후 자동으로 처리됨
        shouldScrollToBottomAfterNextReload = true
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
            // 파일 첨부가 있고 이미지가 없으면 파일 전용 셀 사용
            if message.hasFiles && message.images.isEmpty {
                guard let cell = tableView.dequeueReusableCell(
                    withIdentifier: ChatFileMessageCell.identifier,
                    for: indexPath
                ) as? ChatFileMessageCell,
                      let file = message.files.first else {
                    return UITableViewCell()
                }
                cell.configure(
                    with: file,
                    date: message.date,
                    isOutgoing: message.isOutgoing,
                    showsTime: message.showsTime,
                    showsProfile: message.showsProfile,
                    opponentProfileImagePath: chatRoom.opponent.profileImage
                )

                // 파일 탭 시 뷰어로 열기 (PDF는 전용 뷰어, 그 외는 Quick Look)
                cell.onFileTapped = { [weak self] in
                    self?.openFile(file: file)
                }

                return cell
            }

            // 일반 메시지 셀 (텍스트, 이미지, 또는 혼합)
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
            cell.onImageTapped = { [weak self] images, tappedIndex in
                guard let self = self else { return }
                // 탭한 아이템이 비디오인지 확인
                if case .video(_, let videoURL, let isLocal) = images[tappedIndex] {
                    self.playVideo(videoURL: videoURL, isLocal: isLocal)
                } else {
                    self.showImageViewer(images: images, selectedIndex: tappedIndex)
                }
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
        // 스크롤뷰가 하단에 있는지 확인
        let scrollView = messageTableView
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let contentOffsetY = scrollView.contentOffset.y
        let bottomInset = scrollView.contentInset.bottom

        // 스크롤뷰가 거의 하단에 있는지 확인 (여유 50pt)
        let isNearBottom = contentOffsetY + scrollViewHeight + bottomInset >= contentHeight - 50

        // 스크롤뷰가 하단에 있을 때만 키보드와 함께 스크롤되도록 플래그 설정
        isTextViewBeingEdited = !isNearBottom


        // placeholder 위치 조정 (멀티라인일 때 상단 정렬)
        placeholderLabel.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalToSuperview().offset(textView.textContainerInset.top)
        }

        // 다음 런루프에서 플래그 해제 (키보드 애니메이션 이후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isTextViewBeingEdited = false
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        // 편집 종료 시 플래그 해제
        isTextViewBeingEdited = false

        // 텍스트가 비어있을 때 placeholder를 중앙으로 복귀
        if textView.text.isEmpty {
            placeholderLabel.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(8)
                make.trailing.equalToSuperview().offset(-12)
                make.centerY.equalToSuperview()
            }
        }
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

        // 2. 이미지와 비디오가 모두 없으면 숨김
        if images.isEmpty && pendingVideos.isEmpty {
            selectedImagesScrollView.isHidden = true
            selectedImagesHeightConstraint?.update(offset: 0)
            UIView.animate(withDuration: 0.25) {
                self.view.layoutIfNeeded()
            }
            return
        }

        // 3. 이미지 썸네일 생성
        for (index, image) in images.enumerated() {
            let thumbnailContainer = createThumbnailView(image: image, index: index, isVideo: false)
            selectedImagesStackView.addArrangedSubview(thumbnailContainer)
        }

        // 4. 비디오 썸네일 생성
        for (index, (_, thumbnail)) in pendingVideos.enumerated() {
            let globalIndex = images.count + index
            if let thumb = thumbnail {
                let thumbnailContainer = createThumbnailView(image: thumb, index: globalIndex, isVideo: true)
                selectedImagesStackView.addArrangedSubview(thumbnailContainer)
            }
        }

        // 5. 스크롤뷰 표시 및 높이 조정
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
    ///   - 재생 아이콘 (비디오인 경우)
    ///
    func createThumbnailView(image: UIImage, index: Int, isVideo: Bool) -> UIView {
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

        // 비디오인 경우 재생 아이콘 추가
        if isVideo {
            let playIconView = UIImageView(image: UIImage(systemName: "play.circle.fill"))
            playIconView.tintColor = .white
            playIconView.contentMode = .scaleAspectFit
            containerView.addSubview(playIconView)
            playIconView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(32)
            }
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

    /// X 버튼 탭 시 해당 이미지/비디오 제거
    @objc func removeImageButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        var images = selectedImagesSubject.value

        // pendingImages의 총 개수
        let totalCount = images.count + pendingVideos.count

        guard index < totalCount else { return }

        // 이미지 개수보다 작으면 이미지 제거
        if index < images.count {
            images.remove(at: index)
            selectedImagesSubject.send(images)
            pendingImages.remove(at: index)
        } else {
            // 비디오 제거
            let videoIndex = index - images.count
            if videoIndex < pendingVideos.count {
                pendingVideos.remove(at: videoIndex)
                // pendingImages에서도 제거
                if index < pendingImages.count {
                    pendingImages.remove(at: index)
                }
            }
        }

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
        var loadedItems: [(image: UIImage?, videoURL: URL?)] = Array(repeating: (nil, nil), count: results.count)

        for (index, result) in results.enumerated() {
            let provider = result.itemProvider

            // 동영상 확인
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) ||
               provider.hasItemConformingToTypeIdentifier(UTType.video.identifier) {
                dispatchGroup.enter()
                loadVideo(from: provider) { videoURL in
                    defer { dispatchGroup.leave() }
                    if let url = videoURL {
                        loadedItems[index] = (nil, url)
                    }
                }
                continue
            }

            // 이미지 확인
            guard provider.canLoadObject(ofClass: UIImage.self) else { continue }

            dispatchGroup.enter()
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                defer { dispatchGroup.leave() }
                if let image = object as? UIImage {
                    loadedItems[index] = (image, nil)
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }

            // 이미지와 동영상 분리
            let images = loadedItems.compactMap { $0.image }
            let videoURLs = loadedItems.compactMap { $0.videoURL }

            // 동영상 처리
            var newPendingVideos: [(url: URL, thumbnail: UIImage?)] = []
            for videoURL in videoURLs {
                let thumbnail = self.makeVideoThumbnail(from: videoURL)
                newPendingVideos.append((url: videoURL, thumbnail: thumbnail))
            }
            self.pendingVideos = newPendingVideos

            // pendingImages 업데이트 (이미지 + 동영상 썸네일)
            var allImages = images.map { ChatImageSource.local($0) }
            for (_, thumbnail) in newPendingVideos {
                if let thumb = thumbnail {
                    allImages.append(.local(thumb))
                }
            }
            self.pendingImages = allImages

            // ViewModel에 UIImage 배열 전달 (이미지만)
            self.selectedImagesSubject.send(images)

            // 이미지 미리보기 UI 업데이트
            self.updateSelectedImagesPreview()

            self.updateSendButtonState()
        }
    }

    private func loadVideo(from provider: NSItemProvider, completion: @escaping (URL?) -> Void) {
        let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            ? UTType.movie.identifier
            : UTType.video.identifier

        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { fileURL, _ in
            guard let fileURL else {
                completion(nil)
                return
            }

            // 비디오를 임시 디렉토리에 복사 (원본 URL은 접근 권한이 제한됨)
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = fileURL.lastPathComponent
            let tempURL = tempDirectory.appendingPathComponent(fileName)

            do {
                // 기존 파일 삭제
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }

                // 복사
                try FileManager.default.copyItem(at: fileURL, to: tempURL)
                completion(tempURL)
            } catch {
                completion(nil)
            }
        }
    }

    private func makeVideoThumbnail(from fileURL: URL) -> UIImage? {
        let asset = AVAsset(url: fileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        if let imageRef = try? generator.copyCGImage(at: time, actualTime: nil) {
            return UIImage(cgImage: imageRef)
        }
        return nil
    }

    private func uploadAndSendVideos() {
        guard !pendingVideos.isEmpty else { return }

        for (videoURL, _) in pendingVideos {
            do {
                let videoData = try Data(contentsOf: videoURL)
                let fileName = videoURL.lastPathComponent
                let fileExtension = videoURL.pathExtension.lowercased()

                // MIME Type 결정
                let mimeType: String
                switch fileExtension {
                case "mp4":
                    mimeType = "video/mp4"
                case "mov":
                    mimeType = "video/quicktime"
                case "m4a":
                    mimeType = "audio/mp4"
                case "mp3":
                    mimeType = "audio/mpeg"
                default:
                    mimeType = "video/mp4"
                }

                // ViewModel을 통해 파일 전송
                viewModel.sendFile(
                    data: videoData,
                    fileName: fileName,
                    mimeType: mimeType
                ) { [weak self] success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            self?.scrollToBottom(animated: true)
                        } else if let error = errorMessage {
                            self?.showErrorAlert(message: error)
                        }
                    }
                }
            } catch {
                showErrorAlert(message: "비디오 파일을 읽는데 실패했습니다.")
            }
        }

        // 전송 후 초기화
        pendingVideos.removeAll()
    }
}

// MARK: - Message Actions
private extension ChatRoomViewController {
    /// 실패한 메시지 재전송
    ///
    /// 동작:
    /// 1. 실패한 메시지 찾기
    /// 2. text와 files 정보 추출
    /// 3. ViewModel을 통해 재전송
    /// 4. 재전송 성공 시 새 메시지는 자동으로 가장 아래(최근)에 위치
    ///
    /// - Parameter id: 재전송할 메시지 ID
    func retryMessage(id: String) {
        // 1. 실패한 메시지 찾기
        guard let message = messages.first(where: { $0.id == id }) else { return }

        // 2. text와 files 정보 추출
        let text = message.text
        let files = message.files.map { $0.fileURL }

        // 3. ViewModel을 통해 재전송
        viewModel.retryMessage(messageId: id, text: text, files: files)

        // 4. UI는 ViewModel의 output.messages를 통해 자동 업데이트됨
        // 재전송 성공 시 새 메시지는 가장 최근(아래)에 자동 배치됨
    }
}

// MARK: - UIDocumentPickerDelegate
extension ChatRoomViewController: UIDocumentPickerDelegate {

    /// 파일 선택 완료 시 호출 → 즉시 전송 (Auto-send)
    ///
    /// Security Scoped Resource를 사용하여 안전하게 파일 데이터를 읽고
    /// ViewModel을 통해 서버에 즉시 업로드합니다.
    ///
    /// 주요 처리:
    /// 1. 인증 상태 사전 확인 (Keychain에서 토큰 재확인)
    /// 2. 보안 스코프 접근으로 파일 데이터 읽기
    /// 3. 즉시 ViewModel로 전송 (추가 UI 조작 없이)
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {

        // 1. 인증 상태 사전 확인 (방어 코드)
        // - 파일 처리 전에 먼저 로그인 상태를 확인하여 불필요한 작업 방지
        guard let accessToken = KeychainManager.shared.read(account: "accessToken"),
              !accessToken.isEmpty else {
            showErrorAlert(message: "로그인이 필요합니다. 다시 로그인해주세요.")
            return
        }

        // userId도 재확인
        if currentUserId == nil {
            currentUserId = KeychainManager.shared.read(account: "userId")
        }

        guard currentUserId != nil else {
            showErrorAlert(message: "사용자 정보를 찾을 수 없습니다. 다시 로그인해주세요.")
            return
        }

        // 2. 선택된 파일들 처리
        for url in urls {
            processAndSendFile(url: url)
        }
    }

    /// 파일 URL을 처리하여 즉시 전송
    ///
    /// - Parameter url: 선택된 파일의 URL
    private func processAndSendFile(url: URL) {
        // 보안 스코프 접근 시작 (중요!)
        // 외부 앱에서 선택한 파일은 보안 스코프 내에 있으므로
        // 접근 권한을 명시적으로 획득해야 합니다.
        let isSecurityScoped = url.startAccessingSecurityScopedResource()

        // defer를 사용하여 함수 종료 시 반드시 보안 스코프 접근 해제
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // 파일 정보 추출
        let fileName = url.lastPathComponent
        let mimeType = ChatFileAttachment.mimeType(for: fileName)


        // 파일을 Data로 변환
        do {
            let fileData = try Data(contentsOf: url)

            // 파일 크기 검증 (50MB 제한)
            let maxSize = 50 * 1024 * 1024  // 50MB
            guard fileData.count <= maxSize else {
                let sizeInMB = Double(fileData.count) / (1024 * 1024)
                showErrorAlert(message: "파일 크기는 50MB를 초과할 수 없습니다.\n현재 크기: \(String(format: "%.2f", sizeInMB))MB")
                return
            }


            // ViewModel을 통해 파일 즉시 전송 (인증 헤더는 ViewModel/Repository에서 처리)
            viewModel.sendFile(
                data: fileData,
                fileName: fileName,
                mimeType: mimeType
            ) { [weak self] success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        self?.scrollToBottom(animated: true)
                    } else if let error = errorMessage {
                        self?.showErrorAlert(message: error)
                    }
                }
            }

        } catch {
            showErrorAlert(message: "파일을 읽는데 실패했습니다.")
        }
    }

    /// 파일 선택 취소 시 호출
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    }
}

// MARK: - File Viewer
extension ChatRoomViewController {

    /// 파일 열기 (파일 타입에 따라 분기)
    ///
    /// - PDF: PDFViewerViewController (Coordinator 사용)
    /// - 그 외: Quick Look
    ///
    /// - Parameter file: 파일 첨부 정보
    func openFile(file: ChatFileAttachment) {

        let ext = (file.fileName as NSString).pathExtension.lowercased()

        if ext == "pdf" {
            // Coordinator 지연 초기화 (nil인 경우)
            if chatCoordinator == nil, let nav = navigationController {
                chatCoordinator = ChatCoordinator(
                    navigationController: nav,
                    chatRoomViewController: self
                )
            }

            // PDF는 전용 뷰어로 표시 (Coordinator 사용)
            if let coordinator = chatCoordinator {
                coordinator.showPDFViewer(file: file)
            } else {
                openFileWithQuickLook(file: file)
            }
        } else {
            // 다른 파일 형식은 Quick Look 사용
            openFileWithQuickLook(file: file)
        }
    }

    /// 이미지 뷰어 열기 (갤러리 형태)
    ///
    /// - Parameters:
    ///   - images: 이미지 소스 배열
    ///   - selectedIndex: 선택된 이미지 인덱스
    private func showImageViewer(images: [ChatImageSource], selectedIndex: Int) {

        // Coordinator 지연 초기화 (nil인 경우)
        if chatCoordinator == nil, let nav = navigationController {
            chatCoordinator = ChatCoordinator(
                navigationController: nav,
                chatRoomViewController: self
            )
        }

        // Coordinator를 통해 이미지 뷰어 표시
        if let coordinator = chatCoordinator {
            coordinator.showImageViewer(images: images, selectedIndex: selectedIndex)
        } else {
        }
    }

    /// 비디오 재생
    ///
    /// AVPlayerViewController를 사용하여 비디오를 재생합니다.
    /// - 로컬 비디오: 임시 디렉토리의 파일 재생
    /// - 원격 비디오: 서버 URL로 스트리밍 재생
    ///
    /// - Parameters:
    ///   - videoURL: 비디오 URL (로컬 경로 또는 서버 경로)
    ///   - isLocal: 로컬 파일 여부
    private func playVideo(videoURL: String, isLocal: Bool) {
        let playerURL = isLocal ? URL(fileURLWithPath: videoURL) : normalizedRemoteURL(from: videoURL)

        guard let url = playerURL else {
            showErrorAlert(message: "비디오 URL이 유효하지 않습니다.")
            return
        }

        let playerItem = makePlayerItem(for: url)
        let player = AVPlayer(playerItem: playerItem)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player

        // 재생 시작
        present(playerViewController, animated: true) {
            player.play()
        }
    }

    private func makePlayerItem(for url: URL) -> AVPlayerItem {
        if url.isFileURL {
            return AVPlayerItem(url: url)
        }

        var headers: [String: String] = [
            "SeSACKey": Config.apiKey
        ]
        if let accessToken = KeychainManager.shared.read(account: "accessToken"),
           !accessToken.isEmpty {
            headers["Authorization"] = accessToken
        }

        let asset = AVURLAsset(
            url: url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        return AVPlayerItem(asset: asset)
    }
}

// MARK: - Quick Look
extension ChatRoomViewController: QLPreviewControllerDataSource {

    /// Quick Look으로 파일 열기
    ///
    /// 원격 파일인 경우:
    /// 1. 데이터 다운로드
    /// 2. 임시 폴더에 저장
    /// 3. 로컬 URL로 Quick Look 표시
    ///
    /// - Parameter file: 파일 첨부 정보
    func openFileWithQuickLook(file: ChatFileAttachment) {

        // 원격 URL 생성 (서버 base URL + file path)
        let fullURL = normalizedRemoteURL(from: file.fileURL)

        guard let remoteURL = fullURL else {
            showErrorAlert(message: "유효하지 않은 파일 URL입니다.")
            return
        }

        // 로딩 인디케이터 표시
        let loadingAlert = UIAlertController(
            title: nil,
            message: "파일을 불러오는 중...",
            preferredStyle: .alert
        )
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor).isActive = true
        loadingIndicator.bottomAnchor.constraint(equalTo: loadingAlert.view.bottomAnchor, constant: -20).isActive = true
        present(loadingAlert, animated: true)

        // 파일 다운로드 및 임시 폴더에 저장
        downloadAndSaveFile(from: remoteURL, fileName: file.fileName) { [weak self] result in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let localURL):
                        self?.presentQuickLook(with: localURL)
                    case .failure(let error):
                        self?.showErrorAlert(message: "파일을 불러올 수 없습니다: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// 원격 파일 다운로드 및 임시 폴더 저장
    ///
    /// - Parameters:
    ///   - url: 원격 파일 URL
    ///   - fileName: 저장할 파일명
    ///   - completion: 완료 핸들러 (로컬 URL 또는 에러)
    private func downloadAndSaveFile(
        from url: URL,
        fileName: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 인증 헤더 추가
        var request = URLRequest(url: url)
        if let accessToken = KeychainManager.shared.read(account: "accessToken") {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }
        request.setValue(Config.apiKey, forHTTPHeaderField: "SeSACKey")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // 에러 체크
            if let error = error {
                completion(.failure(error))
                return
            }

            // HTTP 응답 체크
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(
                    domain: "FileDownload",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "서버 응답 오류 (코드: \(statusCode))"]
                )))
                return
            }

            // 데이터 체크
            guard let data = data, !data.isEmpty else {
                completion(.failure(NSError(
                    domain: "FileDownload",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "파일 데이터가 비어있습니다."]
                )))
                return
            }

            // 임시 폴더에 저장
            let tempDirectory = FileManager.default.temporaryDirectory
            let localURL = tempDirectory.appendingPathComponent(fileName)

            do {
                // 기존 파일 삭제 (있는 경우)
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }

                // 새 파일 저장
                try data.write(to: localURL)
                completion(.success(localURL))

            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    /// Quick Look 뷰어 표시
    ///
    /// - Parameter localURL: 로컬 파일 URL
    private func presentQuickLook(with localURL: URL) {
        currentPreviewItem = localURL

        let quickLookController = QLPreviewController()
        quickLookController.dataSource = self
        quickLookController.currentPreviewItemIndex = 0

        present(quickLookController, animated: true)
    }

    // MARK: - QLPreviewControllerDataSource

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return currentPreviewItem != nil ? 1 : 0
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return (currentPreviewItem ?? URL(fileURLWithPath: "")) as QLPreviewItem
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
