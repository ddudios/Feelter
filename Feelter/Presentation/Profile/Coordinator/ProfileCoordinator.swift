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
        let chatRoomListViewController = ChatRoomListViewController()
        navigationController.pushViewController(chatRoomListViewController, animated: true)
    }

    func finish() {
        finishDelegate?.coordinatorDidFinish(childCoordinator: self)
    }

    func loginDidFinish() {
        finishDelegate?.coordinatorDidFinish(childCoordinator: self)
    }
}
