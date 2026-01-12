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
}
