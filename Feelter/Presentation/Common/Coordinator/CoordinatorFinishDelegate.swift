//
//  CoordinatorFinishDelegate.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import Foundation

// Coordinator가 종료될 때 부모에게 알리는 프로토콜
public protocol CoordinatorFinishDelegate: AnyObject {
    func coordinatorDidFinish(childCoordinator: Coordinator)
}
