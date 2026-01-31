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

    @MainActor
    func showFilterDetail(filterId: String) {
        // 이미 같은 필터 상세 화면이 스택에 있는지 확인 (중복 push 방지)
        if let existingVC = navigationController.viewControllers.first(where: { vc in
            if let filterVC = vc as? FilterDetailViewController, filterVC.filterId == filterId {
                return true
            }
            return false
        }) {
            // 이미 있으면 해당 화면으로 pop
            navigationController.popToViewController(existingVC, animated: true)
            return
        }

        // 없으면 새로 push
        let filterDetailViewController = FilterDetailViewController(filterId: filterId)
        navigationController.pushViewController(filterDetailViewController, animated: true)
    }
}
