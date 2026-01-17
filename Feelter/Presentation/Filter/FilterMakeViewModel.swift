//
//  FilterMakeViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/15/26.
//

import Foundation
import Combine
import UIKit

final class FilterMakeViewModel: ViewModelProtocol {

    // MARK: - Input/Output

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let saveButtonTapped: AnyPublisher<ValidatedFilterInput, Never>
    }

    struct Output {
        let mode: AnyPublisher<FilterEditorMode, Never>
        let prefilledData: AnyPublisher<PrefilledFormData?, Never>
        let saveResult: AnyPublisher<Result<FilterDetail, Error>, Never>
        let isLoading: AnyPublisher<Bool, Never>
    }

    // MARK: - Data Types

    struct PrefilledFormData {
        let title: String
        let category: String
        let description: String
        let price: Int
        let previewImageURL: String?
        let metadata: PhotoMetadata?
    }

    struct ValidatedFilterInput {
        let title: String
        let category: String
        let description: String
        let price: Int
        let photo: UIImage
        let metadata: PhotoMetadata
    }

    // MARK: - Properties

    private let mode: FilterEditorMode
    private let repository: FilterRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer

    init(
        mode: FilterEditorMode,
        repository: FilterRepositoryProtocol = DIContainer.shared.resolve(FilterRepositoryProtocol.self)
    ) {
        self.mode = mode
        self.repository = repository
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        let modeSubject = CurrentValueSubject<FilterEditorMode, Never>(mode)
        let prefilledDataSubject = CurrentValueSubject<PrefilledFormData?, Never>(nil)
        let saveResultSubject = PassthroughSubject<Result<FilterDetail, Error>, Never>()
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)

        // viewDidLoad - 수정 모드일 때 기존 데이터로 폼 채우기
        input.viewDidLoad
            .sink { [weak self] in
                guard let self else { return }

                if case .edit(let filterDetail) = self.mode {

                    let prefilled = PrefilledFormData(
                        title: filterDetail.title,
                        category: filterDetail.category.rawValue,
                        description: filterDetail.description,
                        price: filterDetail.price,
                        previewImageURL: filterDetail.previewImages.first,
                        metadata: filterDetail.metadata
                    )

                    prefilledDataSubject.send(prefilled)
                } else {
                }
            }
            .store(in: &cancellables)

        // 저장 버튼 탭 - 모드에 따라 생성 또는 수정 API 호출
        input.saveButtonTapped
            .sink { [weak self] validatedInput in
                guard let self else { return }
                isLoadingSubject.send(true)

                Task {
                    do {
                        let result: FilterDetail

                        switch self.mode {
                        case .create:
                            result = try await self.createFilter(with: validatedInput)
                        case .edit(let existingFilter):
                            result = try await self.updateFilter(
                                id: existingFilter.id,
                                with: validatedInput,
                                existingImages: existingFilter.previewImages
                            )
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
            mode: modeSubject.eraseToAnyPublisher(),
            prefilledData: prefilledDataSubject.eraseToAnyPublisher(),
            saveResult: saveResultSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher()
        )
    }

    // MARK: - Private Methods

    private func createFilter(with input: ValidatedFilterInput) async throws -> FilterDetail {
        // 1. 이미지 데이터 변환
        guard let imageData = input.photo.jpegData(compressionQuality: 0.8) else {
            throw FilterMakeError.imageConversionFailed
        }

        // 2. 파일 업로드 (원본, 필터 적용 - 현재 동일 이미지)
        let fileURLs = try await repository.uploadFiles([imageData, imageData])

        // 3. DTO 변환
        let photoMetadataDTO = input.metadata.toDTO()
        let filterValuesDTO = FilterValues.default.toDTO()

        // 4. 요청 DTO 생성
        let requestDTO = CreateFilterRequestDTO(
            category: input.category,
            title: input.title,
            price: input.price,
            description: input.description,
            files: fileURLs,
            photoMetadata: photoMetadataDTO,
            filterValues: filterValuesDTO
        )

        // 5. API 호출
        return try await repository.createFilter(requestDTO: requestDTO)
    }

    private func updateFilter(
        id: String,
        with input: ValidatedFilterInput,
        existingImages: [String]
    ) async throws -> FilterDetail {
        // 수정 모드에서는 텍스트 필드만 변경 가능
        // 이미지, 메타데이터, 필터값은 변경하지 않음 (nil로 전달하여 기존값 유지)
        let requestDTO = UpdateFilterRequestDTO(
            category: input.category,
            title: input.title,
            price: input.price,
            description: input.description,
            files: nil,             // 이미지 변경 불가
            photoMetadata: nil,     // 메타데이터 변경 불가
            filterValues: nil       // 필터값 변경 불가
        )

        return try await repository.updateFilter(id: id, requestDTO: requestDTO)
    }
}

// MARK: - Error Types

extension FilterMakeViewModel {
    enum FilterMakeError: LocalizedError {
        case imageConversionFailed
        case updateFailed

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed:
                return "이미지 변환에 실패했습니다."
            case .updateFailed:
                return "필터 수정에 실패했습니다."
            }
        }
    }
}
