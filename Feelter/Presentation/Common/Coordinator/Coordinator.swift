//
//  Coordinator.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import UIKit

/// Coordinator Protocol
@MainActor
public protocol Coordinator: AnyObject {

    // 메모리에서 하위 코디네이터들이 해제되지 않도록 보관하는 저장소
    var childCoordinators: [Coordinator] { get set }

    // 앱의 전체적인 View 계층을 관리할 스택
    var navigationController: UINavigationController { get set }

    // 앱의 진입점 역할: SceneDelegate 등에서 최초 호출
    func start()
}

public extension Coordinator {
    /// 자식 Coordinator 추가
    func addChildCoordinator(_ child: Coordinator) {
        childCoordinators.append(child)
    }

    /// 자식 Coordinator 제거 (메모리 관리)
    func removeChildCoordinator(_ child: Coordinator) {
        childCoordinators = childCoordinators.filter { $0 !== child }
    }
}
