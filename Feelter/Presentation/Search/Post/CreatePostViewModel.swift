//
//  CreatePostViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/23/26.
//

import Foundation
import Combine

final class CreatePostViewModel: ViewModelProtocol {

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let saveButtonTapped: AnyPublisher<ValidatedPostInput, Never>
    }

    struct Output {
        let saveResult: AnyPublisher<Result<PostDetail, Error>, Never>
        let isLoading: AnyPublisher<Bool, Never>
    }

    struct ValidatedPostInput {
        let category: String
        let title: String
        let content: String
        let latitude: Double
        let longitude: Double
        let files: [UploadFile]
    }

    private let postUsecase: PostUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()

    init(postUsecase: PostUsecaseProtocol = DIContainer.shared.resolve(PostUsecaseProtocol.self)) {
        self.postUsecase = postUsecase
    }

    func transform(input: Input) -> Output {
        let saveResultSubject = PassthroughSubject<Result<PostDetail, Error>, Never>()
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)

        input.saveButtonTapped
            .sink { [weak self] validatedInput in
                guard let self else { return }
                isLoadingSubject.send(true)

                Task {
                    do {
                        let postInput = CreatePostInput(
                            category: validatedInput.category,
                            title: validatedInput.title,
                            content: validatedInput.content,
                            latitude: validatedInput.latitude,
                            longitude: validatedInput.longitude,
                            files: validatedInput.files
                        )

                        let result = try await self.postUsecase.createPost(input: postInput)

                        await MainActor.run {
                            isLoadingSubject.send(false)
                            saveResultSubject.send(.success(result))
                        }
                    } catch {
                        await MainActor.run {
                            isLoadingSubject.send(false)
                            saveResultSubject.send(.failure(error))
                        }
                    }
                }
            }
            .store(in: &cancellables)

        return Output(
            saveResult: saveResultSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher()
        )
    }
}
