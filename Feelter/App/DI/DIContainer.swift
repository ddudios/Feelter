//
//  DIContainer.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation

final class DIContainer {

    static let shared = DIContainer()

    // Singleton 인스턴스 저장소 (Repository 등)
    private var singletons: [String: Any] = [:]

    // Factory 클로저 저장소 (ViewModel, UseCase 등)
    private var factories: [String: () -> Any] = [:]

    private init() {}

    // MARK: - Singleton 등록
    func registerSingleton<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        singletons[key] = instance
    }

    // MARK: - Factory 등록 (매번 새 인스턴스 생성)
    func registerFactory<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }

    // MARK: - 의존성 해결
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)

        // 1. Singleton 먼저 확인
        if let singleton = singletons[key] as? T {
            return singleton
        }

        // 2. Factory로 생성
        if let factory = factories[key] {
            guard let instance = factory() as? T else {
                fatalError("Factory for '\(type)' returned wrong type")
            }
            return instance
        }

        fatalError("Dependency '\(type)' not registered!")
    }

    // MARK: - 테스트용 초기화
    func reset() {
        singletons.removeAll()
        factories.removeAll()
    }
}
