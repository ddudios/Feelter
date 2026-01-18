//
//  VideoDetailViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation
import Combine

final class VideoDetailViewModel: ViewModelProtocol {

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
    }

    struct Output {
        let videoStream: AnyPublisher<VideoStream?, Never>
        let isLoading: AnyPublisher<Bool, Never>
        let errorMessage: AnyPublisher<String?, Never>
    }

    private let videoId: String
    private let videoSummary: VideoSummary
    private let videoUsecase: VideoUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        videoId: String,
        videoSummary: VideoSummary,
        videoUsecase: VideoUsecaseProtocol
    ) {
        self.videoId = videoId
        self.videoSummary = videoSummary
        self.videoUsecase = videoUsecase
    }

    func transform(input: Input) -> Output {
        let videoStreamSubject = CurrentValueSubject<VideoStream?, Never>(nil)
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let errorMessageSubject = PassthroughSubject<String?, Never>()

        input.viewDidLoad
            .sink { [weak self] _ in
                guard let self = self else { return }
                isLoadingSubject.send(true)

                Task {
                    do {
                        let stream = try await self.videoUsecase.fetchStream(videoId: self.videoId)
                        await MainActor.run {
                            videoStreamSubject.send(stream)
                            isLoadingSubject.send(false)
                        }
                    } catch {
                        await MainActor.run {
                            isLoadingSubject.send(false)
                            errorMessageSubject.send("동영상 스트리밍 정보를 불러오는데 실패했습니다: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .store(in: &cancellables)

        return Output(
            videoStream: videoStreamSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher()
        )
    }

    func getVideoSummary() -> VideoSummary {
        return videoSummary
    }
}
