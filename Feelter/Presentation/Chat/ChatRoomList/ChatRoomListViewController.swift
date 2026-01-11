//
//  ChatRoomListViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import UIKit
import SnapKit

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

    private let chatRoomTableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateView = UIView()
    private let emptyStateImageView = UIImageView()
    private let emptyStateLabel = UILabel()

    private var chatRooms: [ChatRoom] = [] {
        didSet {
            chatRoomTableView.reloadData()
            updateEmptyState()
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        configureEmptyStateView()
        updateEmptyState()
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
        chatRoomTableView.separatorColor = .Feelter.gray90
        chatRoomTableView.separatorInset = UIEdgeInsets(
            top: 0,
            left: Layout.separatorLeftInset,
            bottom: 0,
            right: Layout.separatorRightInset
        )
        chatRoomTableView.rowHeight = Layout.rowHeight
        chatRoomTableView.dataSource = self
        chatRoomTableView.delegate = self
        chatRoomTableView.register(ChatRoomCell.self, forCellReuseIdentifier: ChatRoomCell.identifier)
        chatRoomTableView.tableFooterView = UIView()
        chatRoomTableView.backgroundView = emptyStateView
    }

    private func configureEmptyStateView() {
        emptyStateImageView.image = UIImage.Icon.message
        emptyStateImageView.tintColor = .Feelter.gray75
        emptyStateImageView.contentMode = .scaleAspectFit

        emptyStateLabel.text = "대화를 시작해 보세요"
        emptyStateLabel.font = TextStyle.Pretendard.body1
        emptyStateLabel.textColor = .Feelter.gray75
        emptyStateLabel.textAlignment = .center

        let stackView = UIStackView(arrangedSubviews: [emptyStateImageView, emptyStateLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Layout.emptyStateSpacing

        emptyStateView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Layout.emptyStateHorizontalInset)
            make.centerY.equalToSuperview().offset(-50)
        }

        emptyStateImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.emptyIconSize)
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
        cell.configure(with: chatRoom)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ChatRoomListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
