//
//  CategoryRankingCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import UIKit

final class CategoryRankingCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    @MainActor
    func start() {
        showCategoryRanking(initialCategory: nil)
    }

    @MainActor
    func showCategoryRanking(initialCategory: FilterCategory? = nil) {
        let viewModel = DIContainer.shared.resolve(CategoryRankingViewModel.self)
        let viewController = CategoryRankingViewController(
            viewModel: viewModel,
            initialCategory: initialCategory
        )
        viewController.coordinator = self
        navigationController.pushViewController(viewController, animated: true)
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
