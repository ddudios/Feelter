//
//  ProfileCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit

final public class ProfileCoordinator: Coordinator {

    public var childCoordinators: [Coordinator] = []
    public var navigationController: UINavigationController
    public weak var finishDelegate: CoordinatorFinishDelegate?

    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    public func start() {
        let repository = AuthRepository()
        let usecase = LogoutUsecase(repository: repository)
        let viewModel = ProfileViewModel(logoutUsecase: usecase)
        let vc = ProfileViewController(viewModel: viewModel)
        navigationController.pushViewController(vc, animated: true)
    }

    func finish() {
        finishDelegate?.coordinatorDidFinish(childCoordinator: self)
    }

    func loginDidFinish() {
        finishDelegate?.coordinatorDidFinish(childCoordinator: self)
    }
}
