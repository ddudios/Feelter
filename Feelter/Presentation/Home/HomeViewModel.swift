//
//  HomeViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation
import Combine

final class HomeViewModel: ViewModelProtocol {

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
    }

    struct Output {
        let todayFilter: AnyPublisher<Filter, Never>
        let isLoading: AnyPublisher<Bool, Never>
        let errorMessage: AnyPublisher<String?, Never>
    }

    private let usecase: FilterUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()

    init(usecase: FilterUsecaseProtocol) {
        self.usecase = usecase
    }

    func transform(input: Input) -> Output {
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let todayFilterSubject = PassthroughSubject<Filter, Never>()
        let errorMessageSubject = PassthroughSubject<String?, Never>()

        input.viewDidLoad
            .sink { [weak self] in
                guard let self = self else { return }

                isLoadingSubject.send(true)

                Task {
                    do {
                        let filter = try await self.usecase.fetchTodayFilter()

                        await MainActor.run {
                            isLoadingSubject.send(false)
                            todayFilterSubject.send(filter)
                        }
                    } catch {
                        await MainActor.run {
                            isLoadingSubject.send(false)
                            errorMessageSubject.send("필터를 불러오는데 실패했습니다: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .store(in: &cancellables)

        return Output(
            todayFilter: todayFilterSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher()
        )
    }
}
