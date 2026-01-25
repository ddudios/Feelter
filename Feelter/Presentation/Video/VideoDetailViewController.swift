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

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .medium)
        button.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
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
        cleanupPlayer()
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(playerContainerView)
        view.addSubview(videoInfoView)

        playerContainerView.addSubview(loadingIndicator)
        playerContainerView.addSubview(playPauseButton)
        playerContainerView.addSubview(progressSlider)
        playerContainerView.addSubview(currentTimeLabel)
        playerContainerView.addSubview(durationLabel)

        videoInfoView.addSubview(titleLabel)
        videoInfoView.addSubview(descriptionLabel)
        videoInfoView.addSubview(statsLabel)
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

        playPauseButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(50)
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
    }

    override func configureView() {
        super.configureView()
        title = "Feelter"
    }

    // MARK: - Setup

    private func setupVideoInfo() {
        let summary = viewModel.getVideoSummary()
        titleLabel.text = summary.title
        descriptionLabel.text = summary.description
        statsLabel.text = "조회 \(formatCount(summary.viewCount))회 · 좋아요 \(formatCount(summary.likeCount))개"
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

        print("🎬 [VideoPlayer] 동영상 URL: \(url.absoluteString)")

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
        print("🎬 [VideoPlayer] PlayerItem 상태 관찰 시작")

        statusObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] item, _ in
            DispatchQueue.main.async {
                print("🎬 [VideoPlayer] PlayerItem 상태 변경: \(item.status.rawValue)")

                switch item.status {
                case .readyToPlay:
                    print("✅ [VideoPlayer] 재생 준비 완료")
                    self?.updateDuration()
                    self?.player?.play()
                    self?.isPlaying = true
                    self?.updatePlayPauseButton(isPlaying: true)
                    print("✅ [VideoPlayer] 재생 시작 명령 전송")

                case .failed:
                    let errorMessage = item.error?.localizedDescription ?? "알 수 없는 오류"
                    print("❌ [VideoPlayer] 재생 실패: \(errorMessage)")
                    if let error = item.error {
                        print("❌ [VideoPlayer] 에러 상세: \(error)")
                    }
                    self?.showAlert(message: "동영상 재생에 실패했습니다: \(errorMessage)")

                case .unknown:
                    print("⚠️ [VideoPlayer] 상태: unknown")
                    break

                @unknown default:
                    print("⚠️ [VideoPlayer] 상태: @unknown default")
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
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.videoStream
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stream in
                print("🎬 [VideoPlayer] VideoStream 받음:")
                print("   - streamURL: \(stream.streamURL)")
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
        } else {
            player.play()
            updatePlayPauseButton(isPlaying: true)
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
    }

    @objc private func sliderTouchEnded(_ slider: UISlider) {
        guard let player = player,
              let duration = player.currentItem?.duration else { return }

        let totalSeconds = CMTimeGetSeconds(duration)
        let value = Float64(slider.value) * totalSeconds
        let seekTime = CMTime(value: CMTimeValue(value), timescale: 1)

        player.seek(to: seekTime)
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
    }

    private func updateDuration() {
        guard let duration = player?.currentItem?.duration else { return }
        let totalSeconds = CMTimeGetSeconds(duration)

        if totalSeconds.isFinite {
            durationLabel.text = formatTime(totalSeconds)
        }
    }

    private func updatePlayPauseButton(isPlaying: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .medium)
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
