//
//  ProfileCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit

final public class ProfileCoordinator: Coordinator {

    public var childCoordinators: [Coordinator] = []
    public var navigationController: UINavigationController
    public weak var finishDelegate: CoordinatorFinishDelegate?

    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    public func start() {
        let viewModel = DIContainer.shared.resolve(ProfileViewModel.self)
        let profileViewController = ProfileViewController(viewModel: viewModel)
        profileViewController.onChatListTapped = { [weak self] in
            self?.showChatRoomList()
        }
        navigationController.pushViewController(profileViewController, animated: true)
    }

    func showChatRoomList() {
        // DIContainer에서 ViewModel 주입
        let viewModel = DIContainer.shared.resolve(ChatRoomListViewModel.self)
        let chatRoomListViewController = ChatRoomListViewController(viewModel: viewModel)
        navigationController.pushViewController(chatRoomListViewController, animated: true)
    }

    /// 푸시 알림을 통한 특정 채팅방으로 이동
    ///
    /// - Parameter roomId: 이동할 채팅방 ID
    ///
    /// 동작:
    /// 1. 채팅 목록 화면으로 이동
    /// 2. 특정 채팅방으로 진입 (서버에서 채팅방 정보 조회)
    /// 3. 이미 해당 채팅방이 스택에 있으면 popToViewController, 없으면 새로 push
    public func showChatRoom(roomId: String) {
        // 이미 해당 채팅방이 스택에 있는지 확인
        if let existingChatRoomVC = navigationController.viewControllers.first(where: {
            if let chatRoomVC = $0 as? ChatRoomViewController {
                return chatRoomVC.getCurrentChatRoomId() == roomId
            }
            return false
        }) {
            navigationController.popToViewController(existingChatRoomVC, animated: true)

            // 알림센터의 푸시 배너 제거
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            return
        }

        // 1. 채팅 목록 화면으로 이동 (이미 표시되어 있으면 스킵)
        let isChatListVisible = navigationController.viewControllers.contains { $0 is ChatRoomListViewController }

        if !isChatListVisible {
            showChatRoomList()
        }

        // 2. 채팅방 정보를 서버에서 가져와서 ChatRoomViewController로 이동
        Task { @MainActor in
            do {
                let repository = DIContainer.shared.resolve(ChatRepositoryProtocol.self)

                // 전체 채팅방 목록을 가져와서 해당 roomId를 찾음
                let chatRooms = try await repository.fetchChatRooms()

                if let chatRoom = chatRooms.first(where: { $0.roomId == roomId }) {
                    // ChatRoomViewController 생성 및 이동
                    let fetchChatHistoryUsecase = DIContainer.shared.resolve(FetchChatHistoryUsecase.self)
                    let sendMessageUsecase = DIContainer.shared.resolve(SendMessageUsecase.self)

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

                    navigationController.pushViewController(chatRoomViewController, animated: true)

                    // 푸시로 진입한 경우 스크롤을 최하단으로 (약간의 delay 필요)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        chatRoomViewController.scrollToBottomForPushNavigation()
                    }

                    // 알림센터의 푸시 배너 제거
                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                } else {
                    // roomId에 해당하는 채팅방이 없는 경우
                    showErrorAlert(message: "채팅방을 찾을 수 없습니다.")
                }
            } catch {
                showErrorAlert(message: "채팅방 정보를 불러올 수 없습니다.")
            }
        }
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "오류",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        navigationController.present(alert, animated: true)
    }

    func finish() {
        finishDelegate?.coordinatorDidFinish(childCoordinator: self)
    }

    func loginDidFinish() {
        finishDelegate?.coordinatorDidFinish(childCoordinator: self)
    }
}
