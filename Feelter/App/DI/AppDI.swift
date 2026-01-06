//
//  AppDI.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation

func registerDependencies() {
    let container = DIContainer.shared

    //MARK: - Network
    // NetworkManager는 앱 전체에서 하나만 사용
    let networkManager = NetworkManager()
    container.registerSingleton(NetworkManagerProtocol.self, instance: networkManager)

    //MARK: - Repository
    // Repository도 싱글톤으로 관리 (네트워크 레이어 공유)
    let authRepository = AuthRepository(networkManager: networkManager)
    container.registerSingleton(AuthRepositoryProtocol.self, instance: authRepository)

    let filterRepository = FilterRepository(networkManager: networkManager)
    container.registerSingleton(FilterRepositoryProtocol.self, instance: filterRepository)

    //MARK: - Usecase
    // UseCase는 매번 새로 생성 (상태를 가지지 않음)
    container.registerFactory(LoginUsecaseProtocol.self) {
        let repository = container.resolve(AuthRepositoryProtocol.self)
        return LoginUsecase(repository: repository)
    }

    container.registerFactory(LogoutUsecaseProtocol.self) {
        let repository = container.resolve(AuthRepositoryProtocol.self)
        return LogoutUsecase(repository: repository)
    }

    container.registerFactory(FilterUsecaseProtocol.self) {
        let repository = container.resolve(FilterRepositoryProtocol.self)
        return FilterUsecase(repository: repository)
    }

    //MARK: - ViewModel
    // ViewModel은 화면마다 새로 생성
    container.registerFactory(LoginViewModel.self) {
        let usecase = container.resolve(LoginUsecaseProtocol.self)
        return LoginViewModel(usecase: usecase)
    }

    container.registerFactory(ProfileViewModel.self) {
        let usecase = container.resolve(LogoutUsecaseProtocol.self)
        return ProfileViewModel(logoutUsecase: usecase)
    }

    container.registerFactory(HomeViewModel.self) {
        let usecase = container.resolve(FilterUsecaseProtocol.self)
        return HomeViewModel(usecase: usecase)
    }
}
