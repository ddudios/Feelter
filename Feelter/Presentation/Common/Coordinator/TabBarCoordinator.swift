//
//  TabBarCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit

final class TabBarCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    private let tabBarController: CustomTabBarController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.tabBarController = CustomTabBarController()
    }

    @MainActor
    func start() {
        let viewControllers = createViewControllers()
        tabBarController.setViewControllers(viewControllers, animated: false)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.setViewControllers([tabBarController], animated: false)
    }

    private func createViewControllers() -> [UIViewController] {
        let homeNav = createNavigationController(
            rootViewController: HomeViewController(),
            tabType: .home
        )

        let feedNav = createNavigationController(tabType: .feed)
        let feedCoordinator = FeedCoordinator(navigationController: feedNav)
        addChildCoordinator(feedCoordinator)
        feedCoordinator.start()

        let filterNav = createNavigationController(
            rootViewController: FilterMakeViewController(),
            tabType: .filter
        )

        let searchNav = createNavigationController(
            rootViewController: SearchViewController(),
            tabType: .search
        )

        let profileNav = createNavigationController(tabType: .profile)
        let profileCoordinator = ProfileCoordinator(navigationController: profileNav)
        addChildCoordinator(profileCoordinator)
        profileCoordinator.start()

        return [homeNav, feedNav, filterNav, searchNav, profileNav]
    }

    private func createNavigationController(
        rootViewController: UIViewController? = nil,
        tabType: CustomTabBarController.TabType
    ) -> UINavigationController {
        let navigationController: UINavigationController
        if let rootViewController {
            navigationController = UINavigationController(rootViewController: rootViewController)
        } else {
            navigationController = UINavigationController()
        }
        navigationController.view.backgroundColor = .Feelter.gray100
        navigationController.tabBarItem = UITabBarItem(
            title: tabType.title,
            image: tabType.emptyIcon,
            selectedImage: tabType.fillIcon
        )
        return navigationController
    }

    /// 푸시 알림을 통한 채팅방으로 이동
    ///
    /// - Parameter roomId: 이동할 채팅방 ID
    ///
    /// 동작:
    /// 1. Profile 탭으로 전환
    /// 2. ProfileCoordinator를 통해 채팅방으로 이동
    public func showChatRoom(roomId: String) {
        // Profile 탭으로 전환 (index 4)
        tabBarController.selectedIndex = 4

        // ProfileCoordinator 찾기
        if let profileCoordinator = childCoordinators.first(where: { $0 is ProfileCoordinator }) as? ProfileCoordinator {
            profileCoordinator.showChatRoom(roomId: roomId)
        }
    }
}
