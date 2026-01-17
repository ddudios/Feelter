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
    container.registerSingleton(TokenRepositoryProtocol.self, instance: authRepository)

    let filterRepository = FilterRepository(networkManager: networkManager)
    container.registerSingleton(FilterRepositoryProtocol.self, instance: filterRepository)

    let bannerRepository = BannerRepository(networkManager: networkManager)
    container.registerSingleton(BannerRepositoryProtocol.self, instance: bannerRepository)

    let communityRepository = CommunityRepository(networkManager: networkManager)
    container.registerSingleton(CommunityRepositoryProtocol.self, instance: communityRepository)

    let paymentRepository = PaymentRepository(networkManager: networkManager)
    container.registerSingleton(PaymentRepositoryProtocol.self, instance: paymentRepository)

    // Chat Repository는 CoreData와 Socket.IO도 필요
    let chatRepository = ChatRepository(
        networkManager: networkManager,
        coreDataManager: CoreDataManager.shared,
        socketManager: SocketIOManager.shared
    )
    container.registerSingleton(ChatRepositoryProtocol.self, instance: chatRepository)

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

    container.registerFactory(BannerUsecaseProtocol.self) {
        let repository = container.resolve(BannerRepositoryProtocol.self)
        return BannerUsecase(repository: repository)
    }

    container.registerFactory(PaymentUsecaseProtocol.self) {
        let repository = container.resolve(PaymentRepositoryProtocol.self)
        return PaymentUsecase(repository: repository)
    }

    container.registerFactory(FetchChatRoomsUsecase.self) {
        let repository = container.resolve(ChatRepositoryProtocol.self)
        return FetchChatRoomsUsecase(repository: repository)
    }

    container.registerFactory(FetchChatHistoryUsecase.self) {
        let repository = container.resolve(ChatRepositoryProtocol.self)
        return FetchChatHistoryUsecase(repository: repository)
    }

    container.registerFactory(SendMessageUsecase.self) {
        let repository = container.resolve(ChatRepositoryProtocol.self)
        return SendMessageUsecase(repository: repository)
    }

    container.registerFactory(CreateChatRoomUsecase.self) {
        let repository = container.resolve(ChatRepositoryProtocol.self)
        return CreateChatRoomUsecase(repository: repository)
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
        let filterUsecase = container.resolve(FilterUsecaseProtocol.self)
        let bannerUsecase = container.resolve(BannerUsecaseProtocol.self)
        let tokenRepository = container.resolve(TokenRepositoryProtocol.self)
        return HomeViewModel(filterUsecase: filterUsecase, bannerUsecase: bannerUsecase, tokenRepository: tokenRepository)
    }

    container.registerFactory(CategoryRankingViewModel.self) {
        let filterUsecase = container.resolve(FilterUsecaseProtocol.self)
        return CategoryRankingViewModel(filterUsecase: filterUsecase)
    }

    container.registerFactory(ChatRoomListViewModel.self) {
        let fetchChatRoomsUsecase = container.resolve(FetchChatRoomsUsecase.self)
        let repository = container.resolve(ChatRepositoryProtocol.self)
        return ChatRoomListViewModel(
            fetchChatRoomsUsecase: fetchChatRoomsUsecase,
            repository: repository
        )
    }
}
