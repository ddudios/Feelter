//
//  TabBarCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit
import PhotosUI
import Combine

@MainActor
final class TabBarCoordinator: Coordinator, CustomTabBarControllerDelegate {

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    private let tabBarController: CustomTabBarController
    private weak var filterNavigationController: UINavigationController?
    private var cancellables = Set<AnyCancellable>()
    private var photoPickerDelegateProxy: PhotoPickerDelegateProxy?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.tabBarController = CustomTabBarController()
        bindBackgroundFilterExportEvents()
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

    /// 미완료 결제 복구를 위한 필터 상세 화면으로 이동
    ///
    /// - Parameter filterId: 이동할 필터 ID
    ///
    /// 동작:
    /// 1. Home 탭으로 전환
    /// 2. HomeCoordinator를 통해 필터 상세로 이동
    public func showFilterDetail(filterId: String) {
        // Home 탭으로 전환 (index 0)
        tabBarController.selectedIndex = 0

        // HomeCoordinator 찾기
        if let homeCoordinator = childCoordinators.first(where: { $0 is HomeCoordinator }) as? HomeCoordinator {
            homeCoordinator.showFilterDetail(filterId: filterId)
        }
    }

    @MainActor
    func customTabBarControllerDidSelectFilter(_ controller: CustomTabBarController) {
        presentFilterSelectionActionSheet(from: controller)
    }

    @MainActor
    private func presentFilterSelectionActionSheet(from controller: CustomTabBarController) {
        let actionSheetController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )

        let filterAction = UIAlertAction(title: "필터 생성", style: .default) { [weak self] _ in
            self?.showFilterMake()
        }
        let postAction = UIAlertAction(title: "게시글 작성", style: .default) { [weak self] _ in
            self?.showCreatePost()
        }
        let applyFilterAction = UIAlertAction(title: "필터 적용", style: .default) { [weak self] _ in
            self?.showApplyFilter()
        }
        let cancelAction = UIAlertAction(title: "취소", style: .cancel)

        actionSheetController.addAction(filterAction)
        actionSheetController.addAction(postAction)
        actionSheetController.addAction(applyFilterAction)
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

    @MainActor
    private func showApplyFilter() {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)
        let delegateProxy = PhotoPickerDelegateProxy { [weak self] picker, results in
            picker.dismiss(animated: true)
            self?.photoPickerDelegateProxy = nil
            self?.handlePickedImageForFilterApply(results: results)
        }

        photoPickerDelegateProxy = delegateProxy
        picker.delegate = delegateProxy
        tabBarController.present(picker, animated: true)
    }

    @MainActor
    private func handlePickedImageForFilterApply(results: [PHPickerResult]) {
        guard let result = results.first,
              result.itemProvider.canLoadObject(ofClass: UIImage.self) else {
            return
        }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let image = object as? UIImage else {
                    self.showExportFailureAlert(message: "이미지를 불러오지 못했습니다.")
                    return
                }

                let fetchMyFiltersUsecase = DIContainer.shared.resolve(FetchMyFiltersUsecase.self)
                let viewModel = ApplyFilterViewModel(
                    originalImage: image,
                    fetchMyFiltersUsecase: fetchMyFiltersUsecase,
                    mode: .exportToPhotoLibrary
                )
                let viewController = ApplyFilterViewController(viewModel: viewModel)

                guard let filterNavigationController = self.filterNavigationController else { return }
                let rootViewController = filterNavigationController.viewControllers.first ?? FilterMakeViewController()
                filterNavigationController.setViewControllers([rootViewController, viewController], animated: false)
            }
        }
    }

    private func bindBackgroundFilterExportEvents() {
        BackgroundFilterExportManager.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.handleBackgroundFilterExportEvent(event)
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func handleBackgroundFilterExportEvent(_ event: BackgroundFilterExportEvent) {
        switch event {
        case .succeeded:
            GlobalToastPresenter.shared.show(
                message: "사진첩에 저장이 완료되었습니다.",
                duration: 3
            )
        case .failed(let message):
            showExportFailureAlert(message: message)
        }
    }

    @MainActor
    private func showExportFailureAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))

        if let topViewController = getTopViewController() {
            topViewController.present(alert, animated: true)
        }
    }

    private func getTopViewController() -> UIViewController? {
        var topViewController = navigationController.viewControllers.first

        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }

        if let tabBarController = topViewController as? UITabBarController {
            topViewController = tabBarController.selectedViewController
        }

        if let navigationController = topViewController as? UINavigationController {
            topViewController = navigationController.viewControllers.last
        }

        return topViewController
    }
}

private final class PhotoPickerDelegateProxy: NSObject, PHPickerViewControllerDelegate {

    private let didFinishPicking: (PHPickerViewController, [PHPickerResult]) -> Void

    init(didFinishPicking: @escaping (PHPickerViewController, [PHPickerResult]) -> Void) {
        self.didFinishPicking = didFinishPicking
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        didFinishPicking(picker, results)
    }
}
