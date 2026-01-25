//
//  VideoDetailViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import UIKit
import AVFoundation
import SnapKit
import Combine

final class VideoDetailViewController: BaseViewController {

    weak var coordinator: FeedCoordinator?

    private let viewModel: VideoDetailViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var timeObserverToken: Any?
    private var statusObserver: NSKeyValueObservation?
    private var isPlaying = false

    // MARK: - UI Components

    private lazy var playerContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()

    private lazy var controlsBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.alpha = 1
        return view
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular, scale: .large)
        button.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        return button
    }()

    private lazy var progressSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.minimumTrackTintColor = .Feelter.brightTurquoise
        slider.maximumTrackTintColor = .white.withAlphaComponent(0.3)
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchEnded), for: [.touchUpInside, .touchUpOutside])
        return slider
    }()

    private lazy var currentTimeLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .white
        label.text = "00:00"
        return label
    }()

    private lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .white
        label.text = "00:00"
        return label
    }()

    private lazy var likeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "heart"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(likeButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var subtitleLanguageButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "captions.bubble"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(subtitleLanguageButtonTapped), for: .touchUpInside)
        return button
    }()

    private var isLiked = false

    private lazy var videoInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = .Feelter.gray100
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.title2
        label.textColor = .Feelter.gray60
        label.numberOfLines = 0
        return label
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body2
        label.textColor = .Feelter.gray45
        label.numberOfLines = 0
        return label
    }()

    private lazy var statsLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .Feelter.gray30
        return label
    }()

    private lazy var subtitleTableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.register(SubtitleCell.self, forCellReuseIdentifier: SubtitleCell.identifier)
        table.delegate = self
        table.dataSource = self
        return table
    }()

    private var subtitleItems: [SubtitleItem] = []
    private var currentHighlightedIndex: Int?
    private var isUserScrolling = false
    private let subtitleLanguageSubject = PassthroughSubject<String, Never>()

    private var controlsHideTimer: Timer?
    private var areControlsVisible = true

    // MARK: - Initialization

    init(viewModel: VideoDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayerNotifications()
        setupGestures()
        bind()
        setupVideoInfo()
        viewDidLoadSubject.send(())
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerContainerView.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }

    deinit {
        controlsHideTimer?.invalidate()
        cleanupPlayer()
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(playerContainerView)
        view.addSubview(videoInfoView)

        playerContainerView.addSubview(loadingIndicator)
        playerContainerView.addSubview(controlsBackgroundView)
        playerContainerView.addSubview(playPauseButton)
        playerContainerView.addSubview(progressSlider)
        playerContainerView.addSubview(currentTimeLabel)
        playerContainerView.addSubview(durationLabel)
        playerContainerView.addSubview(likeButton)
        playerContainerView.addSubview(subtitleLanguageButton)

        videoInfoView.addSubview(titleLabel)
        videoInfoView.addSubview(descriptionLabel)
        videoInfoView.addSubview(statsLabel)
        videoInfoView.addSubview(subtitleTableView)
    }

    override func configureLayout() {
        super.configureLayout()

        playerContainerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(playerContainerView.snp.width).multipliedBy(9.0 / 16.0)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        controlsBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        playPauseButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(44)
        }

        progressSlider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-40)
        }

        currentTimeLabel.snp.makeConstraints { make in
            make.leading.equalTo(progressSlider)
            make.top.equalTo(progressSlider.snp.bottom).offset(8)
        }

        durationLabel.snp.makeConstraints { make in
            make.trailing.equalTo(progressSlider)
            make.top.equalTo(progressSlider.snp.bottom).offset(8)
        }

        subtitleLanguageButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.width.height.equalTo(32)
        }

        likeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.trailing.equalTo(subtitleLanguageButton.snp.leading).offset(-12)
            make.width.height.equalTo(32)
        }

        videoInfoView.snp.makeConstraints { make in
            make.top.equalTo(playerContainerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        statsLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        subtitleTableView.snp.makeConstraints { make in
            make.top.equalTo(statsLabel.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func configureView() {
        super.configureView()
        title = "Feelter"
    }

    // MARK: - Setup

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(playerContainerTapped))
        playerContainerView.addGestureRecognizer(tapGesture)
    }

    private func setupVideoInfo() {
        let summary = viewModel.getVideoSummary()
        titleLabel.text = summary.title
        descriptionLabel.text = summary.description
        statsLabel.text = "조회 \(formatCount(summary.viewCount))회 · 좋아요 \(formatCount(summary.likeCount))개"

        isLiked = summary.isLiked
        updateLikeButton()
    }

    private func setupPlayer(with stream: VideoStream) {
        let finalURL: URL?

        if stream.streamURL.hasPrefix("http://") || stream.streamURL.hasPrefix("https://") {
            finalURL = URL(string: stream.streamURL)
        } else {
            let baseURLString = Config.baseURL.absoluteString
            let cleanedBase = baseURLString.hasSuffix("/") ? String(baseURLString.dropLast()) : baseURLString

            var path = stream.streamURL

            // ✅ /data/ 경로는 정적 파일이므로 /v1/ 붙이지 않음
            if path.hasPrefix("/data/") {
                // 정적 파일 경로 (이미지, 동영상 등)
                // 그대로 사용
            } else if path.hasPrefix("/") && !path.hasPrefix("/v1/") {
                // API 경로에만 /v1/ 추가
                path = "/v1" + path
            } else if !path.hasPrefix("/") {
                path = "/v1/" + path
            }

            finalURL = URL(string: cleanedBase + path)
        }

        guard let url = finalURL else {
            showAlert(message: "잘못된 스트리밍 URL입니다.")
            return
        }

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        if #available(iOS 13.0, *) {
            playerItem.automaticallyHandlesInterstitialEvents = false
        }

        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = playerContainerView.bounds

        if let playerLayer = playerLayer {
            playerContainerView.layer.insertSublayer(playerLayer, at: 0)
        }

        observePlayerItemStatus(playerItem)
        addPeriodicTimeObserver()
        disableSubtitles(for: playerItem)
    }

    private func disableSubtitles(for playerItem: AVPlayerItem) {
        Task {
            try? await playerItem.asset.loadValuesAsynchronously(
                forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"]
            )

            if let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                playerItem.select(nil, in: group)
            }
        }
    }

    private func observePlayerItemStatus(_ playerItem: AVPlayerItem) {
        statusObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.updateDuration()
                    self?.player?.play()
                    self?.isPlaying = true
                    self?.updatePlayPauseButton(isPlaying: true)
                    self?.resetControlsHideTimer()

                case .failed:
                    let errorMessage = item.error?.localizedDescription ?? "알 수 없는 오류"
                    self?.showAlert(message: "동영상 재생에 실패했습니다: \(errorMessage)")

                case .unknown:
                    break

                @unknown default:
                    break
                }
            }
        }
    }

    private func setupPlayerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlayToEndTime),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemPlaybackStalled),
            name: .AVPlayerItemPlaybackStalled,
            object: nil
        )
    }

    // MARK: - Binding

    private func bind() {
        let input = VideoDetailViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            subtitleLanguageSelected: subtitleLanguageSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.videoStream
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stream in
                self?.setupPlayer(with: stream)
            }
            .store(in: &cancellables)

        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.loadingIndicator.startAnimating()
                } else {
                    self?.loadingIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)

        output.subtitleItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.subtitleItems = items
                self?.subtitleTableView.reloadData()
            }
            .store(in: &cancellables)

        output.errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showAlert(message: message)
            }
            .store(in: &cancellables)
    }

    // MARK: - Player Control

    @objc private func playPauseTapped() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
            updatePlayPauseButton(isPlaying: false)
            controlsHideTimer?.invalidate()  // 일시정지 시 타이머 중지
        } else {
            player.play()
            updatePlayPauseButton(isPlaying: true)
            resetControlsHideTimer()  // 재생 시 타이머 시작
        }

        isPlaying.toggle()
    }

    @objc private func sliderValueChanged(_ slider: UISlider) {
        guard let player = player,
              let duration = player.currentItem?.duration else { return }

        let totalSeconds = CMTimeGetSeconds(duration)
        let value = Float64(slider.value) * totalSeconds
        let seekTime = CMTime(value: CMTimeValue(value), timescale: 1)

        currentTimeLabel.text = formatTime(value)
        resetControlsHideTimer()  // 슬라이더 조작 시 타이머 리셋
    }

    @objc private func sliderTouchEnded(_ slider: UISlider) {
        guard let player = player,
              let duration = player.currentItem?.duration else { return }

        let totalSeconds = CMTimeGetSeconds(duration)
        let value = Float64(slider.value) * totalSeconds
        let seekTime = CMTime(value: CMTimeValue(value), timescale: 1)

        player.seek(to: seekTime)
        resetControlsHideTimer()  // seek 완료 시 타이머 리셋
    }

    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        updatePlayPauseButton(isPlaying: false)
        player?.seek(to: .zero)
        progressSlider.value = 0
    }

    @objc private func playerItemFailedToPlayToEndTime(_ notification: Notification) {
        showAlert(message: "동영상 재생 중 오류가 발생했습니다.")
    }

    @objc private func playerItemPlaybackStalled(_ notification: Notification) {
    }

    @objc private func playerContainerTapped() {
        if areControlsVisible {
            hideControls()
        } else {
            showControls()
        }
    }

    @objc private func likeButtonTapped() {
        isLiked.toggle()
        updateLikeButton()

        Task {
            do {
                _ = try await viewModel.getVideoUsecase().likeVideo(videoId: viewModel.getVideoSummary().id, status: isLiked)
            } catch {
                // 에러 발생 시 원래 상태로 되돌림
                await MainActor.run {
                    isLiked.toggle()
                    updateLikeButton()
                    showAlert(message: "좋아요 처리에 실패했습니다.")
                }
            }
        }
    }

    @objc private func subtitleLanguageButtonTapped() {
        // 자막 언어 선택 액션 시트 표시
        showSubtitleLanguageActionSheet()
    }

    private func updateLikeButton() {
        let imageName = isLiked ? "heart.fill" : "heart"
        likeButton.setImage(UIImage(systemName: imageName), for: .normal)
    }

    private func showSubtitleLanguageActionSheet() {
        let alert = UIAlertController(title: "자막 언어 선택", message: nil, preferredStyle: .actionSheet)

        // 자막 목록 가져오기
        let subtitles = viewModel.getAvailableSubtitles()

        for subtitle in subtitles {
            let action = UIAlertAction(title: subtitle.name, style: .default) { [weak self] _ in
                self?.subtitleLanguageSubject.send(subtitle.language)
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))

        present(alert, animated: true)
    }

    private func showControls() {
        areControlsVisible = true

        UIView.animate(withDuration: 0.3) {
            self.controlsBackgroundView.alpha = 1
            self.playPauseButton.alpha = 1
            self.progressSlider.alpha = 1
            self.currentTimeLabel.alpha = 1
            self.durationLabel.alpha = 1
            self.likeButton.alpha = 1
            self.subtitleLanguageButton.alpha = 1
        }

        resetControlsHideTimer()
    }

    private func hideControls() {
        areControlsVisible = false
        controlsHideTimer?.invalidate()

        UIView.animate(withDuration: 0.3) {
            self.controlsBackgroundView.alpha = 0
            self.playPauseButton.alpha = 0
            self.progressSlider.alpha = 0
            self.currentTimeLabel.alpha = 0
            self.durationLabel.alpha = 0
            self.likeButton.alpha = 0
            self.subtitleLanguageButton.alpha = 0
        }
    }

    private func resetControlsHideTimer() {
        controlsHideTimer?.invalidate()

        // 재생 중일 때만 타이머 시작
        if isPlaying {
            controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.hideControls()
            }
        }
    }

    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserverToken = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            self?.updateProgress(time: time)
        }
    }

    private func updateProgress(time: CMTime) {
        guard let duration = player?.currentItem?.duration else { return }

        let currentSeconds = CMTimeGetSeconds(time)
        let totalSeconds = CMTimeGetSeconds(duration)

        if totalSeconds.isFinite && totalSeconds > 0 {
            progressSlider.value = Float(currentSeconds / totalSeconds)
            currentTimeLabel.text = formatTime(currentSeconds)
        }

        // 자막 하이라이트 및 자동 스크롤
        updateSubtitleHighlight(currentTime: currentSeconds)
    }

    private func updateSubtitleHighlight(currentTime: Double) {
        guard !subtitleItems.isEmpty else { return }

        // 현재 시간에 해당하는 자막 찾기
        if let index = subtitleItems.firstIndex(where: { $0.contains(time: currentTime) }) {
            // 이전 하이라이트와 다른 경우에만 업데이트
            if currentHighlightedIndex != index {
                let previousIndex = currentHighlightedIndex
                currentHighlightedIndex = index

                // 셀 업데이트
                var indexPathsToReload: [IndexPath] = [IndexPath(row: index, section: 0)]
                if let previous = previousIndex {
                    indexPathsToReload.append(IndexPath(row: previous, section: 0))
                }

                subtitleTableView.reloadRows(at: indexPathsToReload, with: .none)

                // 자동 스크롤 (사용자가 스크롤 중이 아닐 때만)
                if !isUserScrolling {
                    subtitleTableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
                }
            }
        }
    }

    private func updateDuration() {
        guard let duration = player?.currentItem?.duration else { return }
        let totalSeconds = CMTimeGetSeconds(duration)

        if totalSeconds.isFinite {
            durationLabel.text = formatTime(totalSeconds)
        }
    }

    private func updatePlayPauseButton(isPlaying: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular, scale: .large)
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
    }

    // MARK: - Cleanup

    private func cleanupPlayer() {
        player?.pause()

        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }

        statusObserver?.invalidate()
        statusObserver = nil

        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil

        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Helper

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }

        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(
            title: "오류",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension VideoDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return subtitleItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SubtitleCell.identifier, for: indexPath) as? SubtitleCell else {
            return UITableViewCell()
        }

        let item = subtitleItems[indexPath.row]
        let isHighlighted = currentHighlightedIndex == indexPath.row
        cell.configure(with: item, isHighlighted: isHighlighted)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension VideoDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = subtitleItems[indexPath.row]
        let seekTime = CMTime(seconds: item.startTime, preferredTimescale: 1)
        player?.seek(to: seekTime)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserScrolling = true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // 스크롤이 끝났고 감속도 없으면 3초 후 자동 스크롤 재개
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.isUserScrolling = false
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // 감속이 끝났으면 3초 후 자동 스크롤 재개
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.isUserScrolling = false
        }
    }
}

