//
//  ChatRoomListViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import UIKit
import SnapKit
import Combine

final class ChatRoomListViewController: BaseViewController {

    private enum Layout {
        static let tableViewHorizontalInset: CGFloat = 0
        static let tableViewVerticalInset: CGFloat = 0
        static let rowHeight: CGFloat = 84
        static let separatorLeftInset: CGFloat = 84
        static let separatorRightInset: CGFloat = 20
        static let emptyIconSize: CGFloat = 48
        static let emptyStateSpacing: CGFloat = 12
        static let emptyStateHorizontalInset: CGFloat = 40
    }

    // MARK: - Properties

    private let viewModel: ChatRoomListViewModel
    private var cancellables = Set<AnyCancellable>()

    private let chatRoomTableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private let emptyStateView = UIView()
    private let emptyStateImageView = UIImageView()
    private let emptyStateLabel = UILabel()

    // Subjects for Input
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let refreshSubject = PassthroughSubject<Void, Never>()
    private let chatRoomSelectedSubject = PassthroughSubject<IndexPath, Never>()

    private var chatRooms: [ChatRoom] = [] {
        didSet {
            chatRoomTableView.reloadData()
            updateEmptyState()
        }
    }

    private var currentUserId: String? {
        return KeychainManager.shared.read(account: "userId")
    }

    // MARK: - Initialization

    init(viewModel: ChatRoomListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        configureEmptyStateView()
        updateEmptyState()
        bind()

        // 초기 로드 트리거
        viewDidLoadSubject.send()
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(chatRoomTableView)
    }

    override func configureLayout() {
        super.configureLayout()
        chatRoomTableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide).inset(
                UIEdgeInsets(
                    top: Layout.tableViewVerticalInset,
                    left: Layout.tableViewHorizontalInset,
                    bottom: Layout.tableViewVerticalInset,
                    right: Layout.tableViewHorizontalInset
                )
            )
        }
    }

    override func configureView() {
        super.configureView()
        title = "채팅"
        configureNavigationBar()
    }

    func updateChatRooms(_ chatRooms: [ChatRoom]) {
        self.chatRooms = chatRooms.filter { $0.lastMessage != nil }
    }

    // MARK: - Private Methods
    private func setupTableView() {
        chatRoomTableView.backgroundColor = .clear
        chatRoomTableView.separatorStyle = .none
        chatRoomTableView.rowHeight = Layout.rowHeight
        chatRoomTableView.dataSource = self
        chatRoomTableView.delegate = self
        chatRoomTableView.register(ChatRoomCell.self, forCellReuseIdentifier: ChatRoomCell.identifier)
        chatRoomTableView.tableFooterView = UIView()
        chatRoomTableView.backgroundView = emptyStateView

        // Pull-to-Refresh 설정
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        chatRoomTableView.refreshControl = refreshControl
    }

    @objc private func handleRefresh() {
        refreshSubject.send()
    }

    /// ViewModel과 바인딩
    private func bind() {
        // Input 생성
        let input = ChatRoomListViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            refreshTrigger: refreshSubject.eraseToAnyPublisher(),
            chatRoomSelected: chatRoomSelectedSubject.eraseToAnyPublisher()
        )

        // Output 구독
        let output = viewModel.transform(input: input)

        // 채팅방 목록 업데이트
        output.chatRooms
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chatRooms in
                self?.updateChatRooms(chatRooms)
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

        // 채팅방 선택 시 화면 이동
        output.selectedChatRoom
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chatRoom in
                self?.navigateToChatRoom(chatRoom)
            }
            .store(in: &cancellables)
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

    private func navigateToChatRoom(_ chatRoom: ChatRoom) {
        // DIContainer에서 의존성 주입
        let repository = DIContainer.shared.resolve(ChatRepositoryProtocol.self)
        let fetchChatHistoryUsecase = DIContainer.shared.resolve(FetchChatHistoryUsecase.self)
        let sendMessageUsecase = DIContainer.shared.resolve(SendMessageUsecase.self)

        // ChatRoomViewModel은 chatRoom 파라미터가 필요하므로 직접 생성
        let chatRoomViewModel = ChatRoomViewModel(
            chatRoom: chatRoom,
            fetchChatHistoryUsecase: fetchChatHistoryUsecase,
            sendMessageUsecase: sendMessageUsecase,
            repository: repository
        )

        let chatRoomViewController = ChatRoomViewController(
            chatRoom: chatRoom,
            viewModel: chatRoomViewModel
        )

        navigationController?.pushViewController(chatRoomViewController, animated: true)
    }

    private func configureEmptyStateView() {
        emptyStateImageView.image = UIImage.Icon.message
        emptyStateImageView.tintColor = .Feelter.gray75
        emptyStateImageView.contentMode = .scaleAspectFit
        // ✅ 크기 고정 (AutoLayout 충돌 방지)
        emptyStateImageView.setContentHuggingPriority(.required, for: .horizontal)
        emptyStateImageView.setContentHuggingPriority(.required, for: .vertical)
        emptyStateImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        emptyStateImageView.setContentCompressionResistancePriority(.required, for: .vertical)

        emptyStateLabel.text = "대화를 시작해 보세요"
        emptyStateLabel.font = TextStyle.Pretendard.body1
        emptyStateLabel.textColor = .Feelter.gray75
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.setContentHuggingPriority(.required, for: .horizontal)
        emptyStateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stackView = UIStackView(arrangedSubviews: [emptyStateImageView, emptyStateLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Layout.emptyStateSpacing

        emptyStateView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview().offset(-50)
            make.centerX.equalToSuperview()
        }

        emptyStateImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.emptyIconSize).priority(.high)
        }
    }

    private func updateEmptyState() {
        emptyStateView.isHidden = !chatRooms.isEmpty
    }

    private func configureNavigationBar() {
        let searchImage = UIImage.TabBar.searchEmpty
        let searchButton = UIBarButtonItem(
            image: searchImage,
            style: .plain,
            target: self,
            action: #selector(searchButtonTapped)
        )
        navigationItem.rightBarButtonItem = searchButton
    }

    @objc private func searchButtonTapped() {
        // TODO: 채팅방 검색 화면 연결
    }
}

// MARK: - UITableViewDataSource
extension ChatRoomListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatRooms.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ChatRoomCell.identifier,
            for: indexPath
        ) as? ChatRoomCell else {
            return UITableViewCell()
        }

        let chatRoom = chatRooms[indexPath.row]
        let hasFailedMessages = viewModel.hasFailedMessages(roomId: chatRoom.roomId)
        // TODO: 읽지 않은 메시지 개수 계산 (Repository에서 가져와야 함)
        // 일단은 0을 전달하여 "N"으로 표시
        cell.configure(
            with: chatRoom,
            currentUserId: currentUserId,
            unreadCount: 0,
            hasFailedMessages: hasFailedMessages
        )
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ChatRoomListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // ViewModel에게 선택 이벤트 전달
        chatRoomSelectedSubject.send(indexPath)
    }
}
