//
//  SearchCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/21/26.
//

import UIKit

final class SearchCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    @MainActor
    func start() {
        let viewModel = DIContainer.shared.resolve(SearchViewModel.self)
        let viewController = SearchViewController(viewModel: viewModel)
        navigationController.setViewControllers([viewController], animated: false)
    }
}
