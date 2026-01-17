//
//  HomeCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import UIKit

final class HomeCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    @MainActor
    func start() {
        let viewModel = DIContainer.shared.resolve(HomeViewModel.self)
        let homeViewController = HomeViewController(viewModel: viewModel)
        homeViewController.coordinator = self
        navigationController.setViewControllers([homeViewController], animated: false)
    }

    @MainActor
    func showCategoryRanking(initialCategory: FilterCategory? = nil) {
        let categoryRankingCoordinator = CategoryRankingCoordinator(
            navigationController: navigationController
        )
        addChildCoordinator(categoryRankingCoordinator)
        categoryRankingCoordinator.showCategoryRanking(initialCategory: initialCategory)
    }
}
