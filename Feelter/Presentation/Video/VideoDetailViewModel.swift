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
        let subtitleLanguageSelected: AnyPublisher<String, Never>
    }

    struct Output {
        let videoStream: AnyPublisher<VideoStream?, Never>
        let availableSubtitles: AnyPublisher<[VideoSubtitle], Never>
        let subtitleItems: AnyPublisher<[SubtitleItem], Never>
        let isLoading: AnyPublisher<Bool, Never>
        let errorMessage: AnyPublisher<String?, Never>
    }

    private let videoId: String
    private let videoSummary: VideoSummary
    private let videoUsecase: VideoUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()
    private var availableSubtitles: [VideoSubtitle] = []

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
        let availableSubtitlesSubject = CurrentValueSubject<[VideoSubtitle], Never>([])
        let subtitleItemsSubject = CurrentValueSubject<[SubtitleItem], Never>([])
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let errorMessageSubject = PassthroughSubject<String?, Never>()

        // 스트리밍 정보 로드
        input.viewDidLoad
            .sink { [weak self] _ in
                guard let self = self else { return }
                isLoadingSubject.send(true)

                Task {
                    do {
                        let stream = try await self.videoUsecase.fetchStream(videoId: self.videoId)
                        await MainActor.run {
                            videoStreamSubject.send(stream)
                            self.availableSubtitles = stream.subtitles
                            availableSubtitlesSubject.send(stream.subtitles)
                            isLoadingSubject.send(false)

                            // 기본 자막 자동 로드
                            if let defaultSubtitle = stream.subtitles.first(where: { $0.isDefault }) {
                                Task {
                                    await self.loadSubtitle(url: defaultSubtitle.url, subtitleItemsSubject: subtitleItemsSubject, errorMessageSubject: errorMessageSubject)
                                }
                            }
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

        // 자막 언어 선택
        input.subtitleLanguageSelected
            .sink { [weak self] language in
                guard let self = self else { return }
                guard let stream = videoStreamSubject.value else { return }
                guard let selectedSubtitle = stream.subtitles.first(where: { $0.language == language }) else { return }

                Task {
                    await self.loadSubtitle(url: selectedSubtitle.url, subtitleItemsSubject: subtitleItemsSubject, errorMessageSubject: errorMessageSubject)
                }
            }
            .store(in: &cancellables)

        return Output(
            videoStream: videoStreamSubject.eraseToAnyPublisher(),
            availableSubtitles: availableSubtitlesSubject.eraseToAnyPublisher(),
            subtitleItems: subtitleItemsSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher()
        )
    }

    private func loadSubtitle(
        url: String,
        subtitleItemsSubject: CurrentValueSubject<[SubtitleItem], Never>,
        errorMessageSubject: PassthroughSubject<String?, Never>
    ) async {
        do {
            let items = try await videoUsecase.fetchSubtitle(url: url)
            await MainActor.run {
                subtitleItemsSubject.send(items)
            }
        } catch {
            await MainActor.run {
                errorMessageSubject.send("자막을 불러오는데 실패했습니다: \(error.localizedDescription)")
            }
        }
    }

    func getVideoSummary() -> VideoSummary {
        return videoSummary
    }

    func getVideoUsecase() -> VideoUsecaseProtocol {
        return videoUsecase
    }

    func getAvailableSubtitles() -> [VideoSubtitle] {
        return availableSubtitles
    }
}
