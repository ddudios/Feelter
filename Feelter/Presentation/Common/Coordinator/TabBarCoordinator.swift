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
    
    func start() {
        let viewControllers = createViewControllers()
        tabBarController.setViewControllers(viewControllers, animated: false)

        // TabBarController를 네비게이션 스택에 설정
        navigationController.setViewControllers([tabBarController], animated: true)
    }

    private func createViewControllers() -> [UIViewController] {
        let homeNav = createNavigationController(
            rootViewController: HomeViewController(),
            tabType: .home
        )

        let feedNav = createNavigationController(
            rootViewController: FeedViewController(),
            tabType: .feed
        )

        let filterNav = createNavigationController(
            rootViewController: FilterViewController(),
            tabType: .filter
        )

        let searchNav = createNavigationController(
            rootViewController: SearchViewController(),
            tabType: .search
        )

        let profileNav = createNavigationController(
            rootViewController: ProfileViewController(),
            tabType: .profile
        )

        return [homeNav, feedNav, filterNav, searchNav, profileNav]
    }

    private func createNavigationController(
        rootViewController: UIViewController,
        tabType: CustomTabBarController.TabType
    ) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.view.backgroundColor = .Feelter.gray100
        navigationController.tabBarItem = UITabBarItem(
            title: tabType.title,
            image: tabType.emptyIcon,
            selectedImage: tabType.fillIcon
        )
        return navigationController
    }
}
