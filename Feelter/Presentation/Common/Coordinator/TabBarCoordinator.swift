//
//  TabBarCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit

final class TabBarCoordinator: Coordinator, CustomTabBarControllerDelegate {

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    private let tabBarController: CustomTabBarController
    private weak var filterNavigationController: UINavigationController?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.tabBarController = CustomTabBarController()
    }

    @MainActor
    func start() {
        let viewControllers = createViewControllers()
        tabBarController.setViewControllers(viewControllers, animated: false)
        tabBarController.tabBarActionDelegate = self
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.setViewControllers([tabBarController], animated: false)
    }

    private func createViewControllers() -> [UIViewController] {
        // Home 탭 - HomeCoordinator 사용
        let homeNav = createNavigationController(tabType: .home)
        let homeCoordinator = HomeCoordinator(navigationController: homeNav)
        addChildCoordinator(homeCoordinator)
        homeCoordinator.start()

        // Feed 탭 - 새로운 FeedViewController (빈 화면)
        let feedNav = createNavigationController(tabType: .feed)
        let feedCoordinator = FeedCoordinator(navigationController: feedNav)
        addChildCoordinator(feedCoordinator)
        feedCoordinator.start()

        // Filter 탭
        let filterNav = createNavigationController(
            rootViewController: FilterMakeViewController(),
            tabType: .filter
        )
        filterNavigationController = filterNav

        // Search 탭
        let searchNav = createNavigationController(tabType: .search)
        let searchCoordinator = SearchCoordinator(navigationController: searchNav)
        addChildCoordinator(searchCoordinator)
        searchCoordinator.start()

        // Profile 탭
        let profileNav = createNavigationController(tabType: .profile)
        let profileCoordinator = ProfileCoordinator(navigationController: profileNav)
        addChildCoordinator(profileCoordinator)
        profileCoordinator.start()

        return [homeNav, feedNav, filterNav, searchNav, profileNav]
    }

    private func createNavigationController(
        rootViewController: UIViewController? = nil,
        tabType: CustomTabBarController.TabType
    ) -> UINavigationController {
        let navigationController: UINavigationController
        if let rootViewController {
            navigationController = UINavigationController(rootViewController: rootViewController)
        } else {
            navigationController = UINavigationController()
        }
        navigationController.view.backgroundColor = .Feelter.gray100
        navigationController.tabBarItem = UITabBarItem(
            title: tabType.title,
            image: tabType.emptyIcon,
            selectedImage: tabType.fillIcon
        )
        return navigationController
    }

    /// 푸시 알림을 통한 채팅방으로 이동
    ///
    /// - Parameter roomId: 이동할 채팅방 ID
    ///
    /// 동작:
    /// 1. Profile 탭으로 전환
    /// 2. ProfileCoordinator를 통해 채팅방으로 이동
    public func showChatRoom(roomId: String) {
        // Profile 탭으로 전환 (index 4)
        tabBarController.selectedIndex = 4

        // ProfileCoordinator 찾기
        if let profileCoordinator = childCoordinators.first(where: { $0 is ProfileCoordinator }) as? ProfileCoordinator {
            profileCoordinator.showChatRoom(roomId: roomId)
        }
    }

    @MainActor
    func customTabBarControllerDidSelectFilter(_ controller: CustomTabBarController) {
        presentFilterSelectionActionSheet(from: controller)
    }

    @MainActor
    private func presentFilterSelectionActionSheet(from controller: CustomTabBarController) {
        let actionSheetController = UIAlertController(
            title: "필터",
            message: "생성할 항목을 선택해주세요.",
            preferredStyle: .actionSheet
        )

        let filterAction = UIAlertAction(title: "필터 생성", style: .default) { [weak self] _ in
            self?.showFilterMake()
        }
        let postAction = UIAlertAction(title: "게시글 작성", style: .default) { [weak self] _ in
            self?.showCreatePost()
        }
        let cancelAction = UIAlertAction(title: "취소", style: .cancel)

        actionSheetController.addAction(filterAction)
        actionSheetController.addAction(postAction)
        actionSheetController.addAction(cancelAction)

        if let popoverController = actionSheetController.popoverPresentationController {
            let anchorView = controller.actionSheetAnchorView()
            popoverController.sourceView = anchorView
            popoverController.sourceRect = controller.actionSheetAnchorRect()
            popoverController.permittedArrowDirections = .down
        }
        controller.present(actionSheetController, animated: true)
    }

    @MainActor
    private func showFilterMake() {
        let viewController = FilterMakeViewController()
        filterNavigationController?.setViewControllers([viewController], animated: false)
    }

    @MainActor
    private func showCreatePost() {
        guard let filterNavigationController else { return }
        let viewModel = DIContainer.shared.resolve(CreatePostViewModel.self)
        let viewController = CreatePostViewController(viewModel: viewModel)
        filterNavigationController.setViewControllers([viewController], animated: false)
    }
}
