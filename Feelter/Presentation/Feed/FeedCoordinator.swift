//
//  FeedCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import UIKit

final class FeedCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    @MainActor
    func start() {
        let viewController = FeedViewController()
        viewController.coordinator = self
        navigationController.setViewControllers([viewController], animated: false)
    }

    @MainActor
    func showFilterDetail(
        filterId: String,
        onLikeStateChanged: ((String, Bool, Int) -> Void)? = nil
    ) {
        let viewController = FilterDetailViewController(filterId: filterId)
        viewController.onLikeStateChanged = onLikeStateChanged
        navigationController.pushViewController(viewController, animated: true)
    }
}
