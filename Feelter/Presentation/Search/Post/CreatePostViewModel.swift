//
//  CreatePostViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/23/26.
//

import Foundation
import Combine

final class CreatePostViewModel: ViewModelProtocol {

    enum Mode {
        case create
        case edit(EditContext)
    }

    struct EditContext {
        let postId: String
        let category: String
        let title: String
        let content: String
        let filePaths: [String]
        let latitude: Double
        let longitude: Double
    }

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
        let newFiles: [UploadFile]
        let existingFilePaths: [String]
    }

    private let postUsecase: PostUsecaseProtocol
    let mode: Mode
    private var cancellables = Set<AnyCancellable>()

    init(
        postUsecase: PostUsecaseProtocol = DIContainer.shared.resolve(PostUsecaseProtocol.self),
        mode: Mode = .create
    ) {
        self.postUsecase = postUsecase
        self.mode = mode
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
                        let result: PostDetail
                        switch self.mode {
                        case .create:
                            let postInput = CreatePostInput(
                                category: validatedInput.category,
                                title: validatedInput.title,
                                content: validatedInput.content,
                                latitude: validatedInput.latitude,
                                longitude: validatedInput.longitude,
                                files: validatedInput.newFiles
                            )
                            result = try await self.postUsecase.createPost(input: postInput)
                        case .edit(let context):
                            let updateInput = UpdatePostInput(
                                postId: context.postId,
                                category: validatedInput.category,
                                title: validatedInput.title,
                                content: validatedInput.content,
                                latitude: validatedInput.latitude,
                                longitude: validatedInput.longitude,
                                newFiles: validatedInput.newFiles,
                                existingFilePaths: validatedInput.existingFilePaths
                            )
                            result = try await self.postUsecase.updatePost(input: updateInput)
                        }

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
