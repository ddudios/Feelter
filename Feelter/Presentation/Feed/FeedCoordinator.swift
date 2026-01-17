//
//  FeedCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
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
}
