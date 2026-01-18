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
        viewController.coordinator = self
        navigationController.setViewControllers([viewController], animated: false)
    }

    func showEditPost(context: CreatePostViewModel.EditContext) {
        let postUsecase = DIContainer.shared.resolve(PostUsecaseProtocol.self)
        let viewModel = CreatePostViewModel(postUsecase: postUsecase, mode: .edit(context))
        let viewController = CreatePostViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }
}
