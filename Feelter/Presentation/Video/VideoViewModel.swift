//
//  VideoViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation
import Combine

final class VideoViewModel: ViewModelProtocol {
    
    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let loadMoreVideos: AnyPublisher<Void, Never>
        let likeButtonTapped: AnyPublisher<(videoId: String, isLiked: Bool), Never>
    }
    
    struct Output {
        let videos: AnyPublisher<[VideoSummary], Never>
        let isLoading: AnyPublisher<Bool, Never>
        let errorMessage: AnyPublisher<String?, Never>
    }
    
    private let videoUsecase: VideoUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()
    private var videos: [VideoSummary] = []
    private var nextCursor: String?
    private var isLoadingMore = false
    
    init(videoUsecase: VideoUsecaseProtocol) {
        self.videoUsecase = videoUsecase
    }
    
    func transform(input: Input) -> Output {
        let videosSubject = CurrentValueSubject<[VideoSummary], Never>([])
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let errorMessageSubject = PassthroughSubject<String?, Never>()

        func loadVideos() {
            isLoadingSubject.send(true)

            Task {
                do {
                    let result = try await videoUsecase.fetchVideoList(next: nil, limit: 20)
                    await MainActor.run {
                        self.videos = result.videos
                        self.nextCursor = result.nextCursor
                        isLoadingSubject.send(false)
                        videosSubject.send(self.videos)
                    }
                } catch {
                    await MainActor.run {
                        isLoadingSubject.send(false)
                        errorMessageSubject.send("영상 목록을 불러오는데 실패했습니다: \(error.localizedDescription)")
                    }
                }
            }
        }

        input.viewDidLoad
            .sink {
                loadVideos()
            }
            .store(in: &cancellables)

        input.loadMoreVideos
            .sink { [weak self] in
                guard let self = self else { return }

                guard !self.isLoadingMore else { return }
                guard let nextCursor = self.nextCursor else { return }

                self.isLoadingMore = true
                isLoadingSubject.send(true)

                Task {
                    do {
                        let result = try await self.videoUsecase.fetchVideoList(next: nextCursor, limit: 20)
                        await MainActor.run {
                            self.videos.append(contentsOf: result.videos)
                            self.nextCursor = result.nextCursor
                            self.isLoadingMore = false
                            isLoadingSubject.send(false)
                            videosSubject.send(self.videos)
                        }
                    } catch {
                        await MainActor.run {
                            self.isLoadingMore = false
                            isLoadingSubject.send(false)
                            errorMessageSubject.send("추가 영상을 불러오는데 실패했습니다: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .store(in: &cancellables)

        input.likeButtonTapped
            .sink { [weak self] videoId, currentIsLiked in
                guard let self = self,
                      let index = self.videos.firstIndex(where: { $0.id == videoId }) else {
                    return
                }

                let originalVideo = self.videos[index]
                let newIsLiked = !currentIsLiked
                let newLikeCount = newIsLiked
                ? originalVideo.likeCount + 1
                : max(0, originalVideo.likeCount - 1)

                self.videos[index] = self.updatedVideo(
                    originalVideo,
                    isLiked: newIsLiked,
                    likeCount: newLikeCount
                )
                videosSubject.send(self.videos)

                Task {
                    do {
                        _ = try await self.videoUsecase.likeVideo(
                            videoId: videoId,
                            status: newIsLiked
                        )
                    } catch {
                        await MainActor.run {
                            guard let revertIndex = self.videos.firstIndex(where: { $0.id == videoId }) else {
                                return
                            }
                            self.videos[revertIndex] = originalVideo
                            videosSubject.send(self.videos)
                            errorMessageSubject.send("좋아요 처리에 실패했습니다.")
                        }
                    }
                }
            }
            .store(in: &cancellables)

        return Output(
            videos: videosSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher()
        )
    }

    private func updatedVideo(
        _ video: VideoSummary,
        isLiked: Bool,
        likeCount: Int
    ) -> VideoSummary {
        return VideoSummary(
            id: video.id,
            fileName: video.fileName,
            title: video.title,
            description: video.description,
            duration: video.duration,
            thumbnailURL: video.thumbnailURL,
            availableQualities: video.availableQualities,
            viewCount: video.viewCount,
            likeCount: likeCount,
            isLiked: isLiked,
            createdAt: video.createdAt
        )
    }
}
