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
        let viewModel = DIContainer.shared.resolve(VideoViewModel.self)
        let viewController = VideoListViewController(viewModel: viewModel)
        viewController.coordinator = self
        navigationController.setViewControllers([viewController], animated: false)
    }

    func showVideoDetail(videoId: String, videoSummary: VideoSummary) {
        let videoUsecase = DIContainer.shared.resolve(VideoUsecaseProtocol.self)
        let viewModel = VideoDetailViewModel(
            videoId: videoId,
            videoSummary: videoSummary,
            videoUsecase: videoUsecase
        )
        let viewController = VideoDetailViewController(viewModel: viewModel)
        viewController.coordinator = self
        navigationController.pushViewController(viewController, animated: true)
    }
}
