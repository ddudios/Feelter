//
//  SearchViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/21/26.
//

import Foundation
import Combine
import CoreLocation

final class SearchViewModel: ViewModelProtocol {

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let refreshTriggered: AnyPublisher<Void, Never>
        let loadMoreTriggered: AnyPublisher<Void, Never>
        let searchRequested: AnyPublisher<String, Never>
        let distanceChanged: AnyPublisher<Int?, Never>
        let locationUpdated: AnyPublisher<CLLocationCoordinate2D, Never>
        let likeButtonTapped: AnyPublisher<(postId: String, isLiked: Bool), Never>
        let deletePostRequested: AnyPublisher<String, Never>
    }

    struct Output {
        let posts: AnyPublisher<[SearchPostItem], Never>
        let isLoading: AnyPublisher<Bool, Never>
        let errorMessage: AnyPublisher<String?, Never>
    }

    private let postUsecase: PostUsecaseProtocol
    private let likePostUsecase: LikePostUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()

    private var posts: [SearchPostItem] = []
    private var nextCursor: String?
    private var isLoadingMore = false
    private var currentQuery = ""
    private var currentMaxDistance: Int?
    private var currentLocation: CLLocationCoordinate2D?
    private var commentCountCache: [String: Int] = [:]
    private var commentFetchInProgress = Set<String>()
    private var locationNameCache: [String: String] = [:]
    private var locationRequestInProgress = Set<String>()
    private var locationKeyByPostId: [String: String] = [:]

    private let fetchLimit = 10

    init(
        postUsecase: PostUsecaseProtocol,
        likePostUsecase: LikePostUsecaseProtocol
    ) {
        self.postUsecase = postUsecase
        self.likePostUsecase = likePostUsecase
    }

    func transform(input: Input) -> Output {
        let postsSubject = CurrentValueSubject<[SearchPostItem], Never>([])
        let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        let errorMessageSubject = PassthroughSubject<String?, Never>()

        func fetchCommentCountsIfNeeded(for postIds: [String]) {
            let ids = Set(postIds).filter {
                commentCountCache[$0] == nil && !commentFetchInProgress.contains($0)
            }
            guard !ids.isEmpty else { return }

            let idSet = Set(ids)
            commentFetchInProgress.formUnion(idSet)

            Task {
                var results: [(String, Int)] = []
                await withTaskGroup(of: (String, Int)?.self) { group in
                    for id in ids {
                        group.addTask { [postUsecase] in
                            do {
                                let detail = try await postUsecase.fetchPostDetail(postId: id)
                                return (id, detail.comments.count)
                            } catch {
                                return nil
                            }
                        }
                    }

                    for await result in group {
                        if let result = result {
                            results.append(result)
                        }
                    }
                }

                await MainActor.run {
                    for (id, count) in results {
                        commentCountCache[id] = count
                    }
                    commentFetchInProgress.subtract(idSet)

                    guard !results.isEmpty else { return }
                    posts = posts.map { item in
                        guard let count = commentCountCache[item.id] else { return item }
                        return updatedPostItem(item, commentCount: count)
                    }
                    postsSubject.send(posts)
                }
            }
        }

        func loadPosts(reset: Bool, shouldEmitLocationError: Bool) {
            if reset {
                nextCursor = nil
                isLoadingMore = false
                locationKeyByPostId.removeAll()
            }

            let locationRequired = currentMaxDistance != nil
            if locationRequired && currentLocation == nil {
                if shouldEmitLocationError {
                    errorMessageSubject.send("위치 정보를 불러올 수 없습니다.")
                }
                isLoadingMore = false
                return
            }

            let location = currentLocation
            let maxDistance = currentMaxDistance
            let shouldIncludeLocation = maxDistance != nil && location != nil
            let longitude = shouldIncludeLocation ? location?.longitude : nil
            let latitude = shouldIncludeLocation ? location?.latitude : nil

            isLoadingSubject.send(true)

            Task {
                do {
                    let result = try await postUsecase.fetchGeolocationPosts(
                        category: nil,
                        longitude: longitude,
                        latitude: latitude,
                        maxDistance: maxDistance,
                        limit: fetchLimit,
                        next: reset ? nil : nextCursor,
                        orderBy: .createdAt
                    )
                    
                    await MainActor.run {
                        let newItems = makePostItems(from: result.posts)
                        
                        if reset {
                            posts = newItems
                        } else {
                            posts.append(contentsOf: newItems)
                        }

                        if let cursor = result.nextCursor, cursor != "0" {
                            nextCursor = cursor
                        } else {
                            nextCursor = nil
                        }

                        isLoadingSubject.send(false)
                        postsSubject.send(posts)
                        isLoadingMore = false
                        fetchCommentCountsIfNeeded(for: newItems.map { $0.id })
                        resolveLocationNamesIfNeeded(for: result.posts, postsSubject: postsSubject)
                    }
                } catch {
                    await MainActor.run {
                        isLoadingSubject.send(false)
                        isLoadingMore = false
                        errorMessageSubject.send("게시글을 불러오는데 실패했습니다.")
                    }
                }
            }
        }

        func searchPosts(query: String) {
            isLoadingSubject.send(true)
            locationKeyByPostId.removeAll()

            Task {
                do {
                    let result = try await postUsecase.searchPosts(title: query)
                    await MainActor.run {
                        let newItems = makePostItems(from: result)
                        posts = newItems
                        nextCursor = nil
                        isLoadingSubject.send(false)
                        postsSubject.send(posts)
                        fetchCommentCountsIfNeeded(for: newItems.map { $0.id })
                        resolveLocationNamesIfNeeded(for: result, postsSubject: postsSubject)
                    }
                } catch {
                    await MainActor.run {
                        isLoadingSubject.send(false)
                        errorMessageSubject.send("검색 결과를 불러오는데 실패했습니다.")
                    }
                }
            }
        }

        input.viewDidLoad
            .sink { [weak self] in
                guard let self = self else { return }
                self.currentMaxDistance = nil
                if self.currentQuery.isEmpty {
                    loadPosts(reset: true, shouldEmitLocationError: false)
                }
            }
            .store(in: &cancellables)

        input.refreshTriggered
            .sink { [weak self] in
                guard let self = self else { return }
                if self.currentQuery.isEmpty {
                    loadPosts(reset: true, shouldEmitLocationError: true)
                } else {
                    searchPosts(query: self.currentQuery)
                }
            }
            .store(in: &cancellables)

        input.loadMoreTriggered
            .sink { [weak self] in
                guard let self = self else { return }
                guard self.currentQuery.isEmpty else { return }
                guard !self.isLoadingMore else { return }
                guard self.nextCursor != nil else { return }
                self.isLoadingMore = true
                loadPosts(reset: false, shouldEmitLocationError: false)
            }
            .store(in: &cancellables)

        input.searchRequested
            .sink { [weak self] text in
                guard let self = self else { return }
                let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.currentQuery = query
                if query.isEmpty {
                    loadPosts(reset: true, shouldEmitLocationError: true)
                } else {
                    searchPosts(query: query)
                }
            }
            .store(in: &cancellables)

        input.distanceChanged
            .sink { [weak self] maxDistance in
                guard let self = self else { return }
                self.currentMaxDistance = maxDistance
                guard self.currentQuery.isEmpty else { return }
                loadPosts(reset: true, shouldEmitLocationError: true)
            }
            .store(in: &cancellables)

        input.locationUpdated
            .sink { [weak self] coordinate in
                guard let self = self else { return }
                self.currentLocation = coordinate
            }
            .store(in: &cancellables)

        input.likeButtonTapped
            .sink { [weak self] postId, currentIsLiked in
                guard let self = self,
                      let index = self.posts.firstIndex(where: { $0.id == postId }) else {
                    return
                }

                let originalPost = self.posts[index]
                let newIsLiked = !currentIsLiked
                let newLikeCount = newIsLiked
                ? originalPost.likeCount + 1
                : max(0, originalPost.likeCount - 1)

                self.posts[index] = self.updatedPostItem(
                    originalPost,
                    isLiked: newIsLiked,
                    likeCount: newLikeCount
                )
                postsSubject.send(self.posts)

                Task {
                    do {
                        _ = try await self.likePostUsecase.execute(
                            postId: postId,
                            isLiked: currentIsLiked
                        )
                    } catch {
                        await MainActor.run {
                            guard let revertIndex = self.posts.firstIndex(where: { $0.id == postId }) else {
                                return
                            }
                            self.posts[revertIndex] = originalPost
                            postsSubject.send(self.posts)
                            errorMessageSubject.send("좋아요 처리에 실패했습니다.")
                        }
                    }
                }
            }
            .store(in: &cancellables)

        input.deletePostRequested
            .sink { [weak self] postId in
                guard let self = self else { return }
                let originalPosts = self.posts
                self.posts.removeAll { $0.id == postId }
                postsSubject.send(self.posts)

                Task {
                    do {
                        try await self.postUsecase.deletePost(postId: postId)
                    } catch {
                        await MainActor.run {
                            self.posts = originalPosts
                            postsSubject.send(self.posts)
                            errorMessageSubject.send("게시글 삭제에 실패했습니다.")
                        }
                    }
                }
            }
            .store(in: &cancellables)

        return Output(
            posts: postsSubject.eraseToAnyPublisher(),
            isLoading: isLoadingSubject.eraseToAnyPublisher(),
            errorMessage: errorMessageSubject.eraseToAnyPublisher()
        )
    }

    private func resolveLocationNamesIfNeeded(
        for posts: [PostSummary],
        postsSubject: CurrentValueSubject<[SearchPostItem], Never>
    ) {
        for post in posts {
            let coordinate = CLLocationCoordinate2D(
                latitude: post.geolocation.latitude,
                longitude: post.geolocation.longitude
            )
            let locationKey = locationCacheKey(for: coordinate)

            if locationNameCache[locationKey] != nil || locationRequestInProgress.contains(locationKey) {
                continue
            }

            locationRequestInProgress.insert(locationKey)
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR")) { [weak self] placemarks, _ in
                guard let self else { return }
                let locationName = self.makeLocationName(from: placemarks?.first) ?? "위치 정보 없음"
                Task { @MainActor in
                    self.locationRequestInProgress.remove(locationKey)
                    self.locationNameCache[locationKey] = locationName
                    self.posts = self.posts.map { item in
                        guard self.locationKeyByPostId[item.id] == locationKey else { return item }
                        return self.updatedPostItem(item, locationText: locationName)
                    }
                    postsSubject.send(self.posts)
                }
            }
        }
    }

    private func locationCacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        let latitude = String(format: "%.4f", coordinate.latitude)
        let longitude = String(format: "%.4f", coordinate.longitude)
        return "\(latitude),\(longitude)"
    }

    private func makeLocationName(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }
        if let subLocality = placemark.subLocality, !subLocality.isEmpty {
            return subLocality
        }
        if let locality = placemark.locality, !locality.isEmpty {
            return locality
        }
        if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
            return administrativeArea
        }
        return nil
    }

    private func makePostItems(from posts: [PostSummary]) -> [SearchPostItem] {
        posts.map { post in
            let nickname = post.creator.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = post.creator.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let authorName = nickname.isEmpty ? name : nickname

            let coordinate = CLLocationCoordinate2D(
                latitude: post.geolocation.latitude,
                longitude: post.geolocation.longitude
            )
            let locationKey = locationCacheKey(for: coordinate)
            locationKeyByPostId[post.id] = locationKey
            let locationText = locationNameCache[locationKey] ?? "위치 확인 중"

            return SearchPostItem(
                id: post.id,
                authorId: post.creator.id,
                authorName: authorName,
                profileImagePath: post.creator.profileImageURL,
                locationText: locationText,
                imagePaths: post.files,
                isLiked: post.isLiked,
                likeCount: post.likeCount,
                commentCount: commentCountCache[post.id] ?? 0,
                title: post.title,
                category: post.category,
                content: post.content,
                timeText: post.createdAt.relativeDescription()
            )
        }
    }

    private func updatedPostItem(
        _ item: SearchPostItem,
        isLiked: Bool? = nil,
        likeCount: Int? = nil,
        commentCount: Int? = nil,
        locationText: String? = nil
    ) -> SearchPostItem {
        SearchPostItem(
            id: item.id,
            authorId: item.authorId,
            authorName: item.authorName,
            profileImagePath: item.profileImagePath,
            locationText: locationText ?? item.locationText,
            imagePaths: item.imagePaths,
            isLiked: isLiked ?? item.isLiked,
            likeCount: likeCount ?? item.likeCount,
            commentCount: commentCount ?? item.commentCount,
            title: item.title,
            category: item.category,
            content: item.content,
            timeText: item.timeText
        )
    }
}
