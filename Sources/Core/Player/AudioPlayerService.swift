import AVFoundation
import Foundation
import Observation
import os

@MainActor
protocol AudioPlaying: AnyObject {
    var state: PlaybackState { get }
    var current: PlayableItem? { get }
    var elapsed: TimeInterval { get }
    /// ICY 메타데이터로 들어온 곡명. 안 주는 방송국이 많아서 없을 수 있다.
    var streamTitle: String? { get }

    func play(_ item: PlayableItem) async
    func pause()
    func resume()
    func stop()
    func next() async
    func previous() async
}

/// 앱에서 유일한 재생 주체.
///
/// 화면은 이 객체의 `state` 만 읽는다. `AVPlayer` 와 `AVAudioSession` 은 밖으로 새지 않는다.
@MainActor
@Observable
final class AudioPlayerService: AudioPlaying {
    private(set) var state: PlaybackState = .idle
    private(set) var current: PlayableItem?
    private(set) var elapsed: TimeInterval = 0
    private(set) var streamTitle: String?

    /// 첫 오디오를 이 시간 안에 못 받으면 실패로 본다.
    static let firstAudioTimeout: Duration = .seconds(15)

    @ObservationIgnored private let resolver: StreamResolving
    @ObservationIgnored private let reporter: StreamReporting
    @ObservationIgnored private let session = AudioSessionManager()
    @ObservationIgnored private let nowPlaying = NowPlayingCenter()
    @ObservationIgnored private let log = Logger(subsystem: "com.zerolive.cloudRadioN", category: "player")

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var itemObserver: NSKeyValueObservation?
    @ObservationIgnored private var rateObserver: NSKeyValueObservation?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var metadataOutput: AVPlayerItemMetadataOutput?
    @ObservationIgnored private var metadataForwarder: MetadataForwarder?
    @ObservationIgnored private var failureObserver: NSObjectProtocol?
    @ObservationIgnored private var watchdog: Task<Void, Never>?

    /// 라이브 스트림은 `currentTime()` 이 0 에서 시작하지 않아 벽시계로 센다.
    @ObservationIgnored private var liveStartedAt: Date?
    @ObservationIgnored private var liveAccumulated: TimeInterval = 0
    /// 인터럽트 때문에 우리가 멈춘 것인지 구분한다.
    @ObservationIgnored private var pausedByInterruption = false

    init(
        resolver: StreamResolving = ProxyStreamResolver(),
        reporter: StreamReporting = ProxyClient()
    ) {
        self.resolver = resolver
        self.reporter = reporter
        wireSession()
        wireRemoteCommands()
    }

    // MARK: - 재생 조작

    func play(_ item: PlayableItem) async {
        teardownCurrentItem()

        current = item
        streamTitle = nil
        elapsed = 0
        liveAccumulated = 0
        liveStartedAt = nil
        state = .loading
        pushNowPlaying()

        let url: URL
        do {
            url = try await resolver.streamURL(for: item)
        } catch {
            log.error("스트림 주소를 못 받았다: \(String(describing: error))")
            fail(.network)
            return
        }

        // 화면을 오래 누르고 있다가 다른 항목으로 넘어갔으면 여기서 버린다.
        guard current?.id == item.id else { return }

        do {
            try session.activate()
        } catch {
            log.error("오디오 세션을 못 켰다: \(String(describing: error))")
            fail(.unknown("audio session"))
            return
        }

        log.info("재생 시도: \(url.absoluteString, privacy: .public)")
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        // 라이브는 앞부분을 받아둬도 쓸모가 없다. 시작을 앞당기는 쪽으로 둔다.
        playerItem.preferredForwardBufferDuration = item.isLive ? 3 : 0

        attachMetadataOutput(to: playerItem)
        observe(playerItem)

        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        observeRate(of: player)
        observeTime(of: player)
        self.player = player

        startWatchdog(for: item.id)
        player.play()
    }

    func pause() {
        guard state == .playing else { return }
        player?.pause()
        accumulateLiveElapsed()
        pausedByInterruption = false
        state = .paused
        pushNowPlaying()
    }

    func resume() {
        guard state == .paused, let player else { return }
        do {
            try session.activate()
        } catch {
            log.error("재개할 때 오디오 세션을 못 켰다: \(String(describing: error))")
            fail(.unknown("audio session"))
            return
        }
        liveStartedAt = Date()
        player.play()
        state = .playing
        pushNowPlaying()
    }

    func stop() {
        teardownCurrentItem()
        session.deactivate()
        current = nil
        streamTitle = nil
        state = .idle
        elapsed = 0
        liveAccumulated = 0
        liveStartedAt = nil
        pushNowPlaying()
    }

    /// 실패한 뒤 사용자가 다시 시도할 때 쓴다.
    func retry() async {
        guard let item = current else { return }
        await play(item)
    }

    func next() async {
        // M3: 프리셋의 다음 소스, 또는 추천 목록의 다음 항목.
    }

    func previous() async {
        // M3: 위와 같다.
    }

    // MARK: - AVPlayer 관찰

    private func observe(_ playerItem: AVPlayerItem) {
        // `change.newValue` 는 쓰지 않는다. ObjC 열거형을 Swift 열거형으로 되돌리지 못해
        // 항상 nil 이 들어온다. 관찰 대상에서 바로 읽는다.
        itemObserver = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            let status = observed.status
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .failed:
                    let message = String(describing: self.player?.currentItem?.error)
                    self.log.error("AVPlayerItem 실패: \(message, privacy: .public)")
                    self.fail(.network)
                case .readyToPlay:
                    self.log.info("AVPlayerItem 준비됨")
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.log.error("끝까지 재생하지 못했다")
                self?.fail(.network)
            }
        }
    }

    private func observeRate(of player: AVPlayer) {
        // 위와 같은 이유로 `change.newValue` 대신 관찰 대상에서 읽는다.
        rateObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observed, _ in
            let status = observed.timeControlStatus
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatus(status)
            }
        }
    }

    private func observeTime(of player: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.handleTick(time)
            }
        }
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            watchdog?.cancel()
            watchdog = nil
            if liveStartedAt == nil { liveStartedAt = Date() }
            if state != .playing {
                log.info("재생 시작됨")
                state = .playing
                pushNowPlaying()
            }
        case .paused:
            // 우리가 부른 `pause()` 는 이미 상태를 바꿨다. 여기서는 덮어쓰지 않는다.
            break
        case .waitingToPlayAtSpecifiedRate:
            // 버퍼를 기다리는 중이다. 이미 재생하던 중이면 상태를 흔들지 않는다.
            break
        @unknown default:
            break
        }
    }

    /// 0.5초마다 온다. 잠금화면은 여기서 갱신하지 않는다.
    /// 라이브는 보여줄 진행 바가 없고, 초마다 밀어 넣으면 낭비다.
    private func handleTick(_ time: CMTime) {
        guard state == .playing else { return }
        if current?.isLive == true {
            let since = liveStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            elapsed = liveAccumulated + since
        } else {
            elapsed = max(0, CMTimeGetSeconds(time))
        }
    }

    private func accumulateLiveElapsed() {
        guard current?.isLive == true, let started = liveStartedAt else { return }
        liveAccumulated += Date().timeIntervalSince(started)
        liveStartedAt = nil
        elapsed = liveAccumulated
    }

    // MARK: - ICY 메타데이터

    private func attachMetadataOutput(to playerItem: AVPlayerItem) {
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        let forwarder = MetadataForwarder(owner: self)
        output.setDelegate(forwarder, queue: .main)
        playerItem.add(output)
        metadataOutput = output
        metadataForwarder = forwarder
    }

    /// `MetadataForwarder` 가 문자열만 뽑아 넘겨준다.
    fileprivate func updateStreamTitle(_ title: String) {
        guard title != streamTitle else { return }
        streamTitle = title
        log.info("ICY 곡명: \(title, privacy: .public)")
        pushNowPlaying()
    }

    // MARK: - 세션과 원격 명령

    private func wireSession() {
        session.onInterruption = { [weak self] interruption in
            guard let self else { return }
            switch interruption {
            case .began:
                if self.state == .playing {
                    self.player?.pause()
                    self.accumulateLiveElapsed()
                    self.state = .paused
                    self.pausedByInterruption = true
                    self.pushNowPlaying()
                }
            case .ended(let shouldResume):
                guard self.pausedByInterruption else { return }
                self.pausedByInterruption = false
                if shouldResume { self.resume() }
            }
        }

        session.onOutputDeviceLost = { [weak self] in
            self?.pause()
        }
    }

    private func wireRemoteCommands() {
        nowPlaying.wire(.init(
            play: { [weak self] in
                guard let self else { return }
                if self.state == .paused { self.resume() } else if self.state == .playing { self.pause() }
            },
            pause: { [weak self] in self?.pause() },
            stop: { [weak self] in self?.stop() },
            next: { [weak self] in Task { await self?.next() } },
            previous: { [weak self] in Task { await self?.previous() } }
        ))
        nowPlaying.setSkipEnabled(false)
    }

    private func pushNowPlaying() {
        nowPlaying.update(
            item: current,
            streamTitle: streamTitle,
            elapsed: elapsed,
            isPlaying: state == .playing
        )
    }

    // MARK: - 실패와 정리

    private func startWatchdog(for itemID: String) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: Self.firstAudioTimeout)
            guard !Task.isCancelled, let self else { return }
            guard self.current?.id == itemID, self.state == .loading else { return }
            self.log.error("15초 안에 첫 오디오가 없었다: \(itemID, privacy: .public)")
            self.fail(.noAudio)
        }
    }

    private func fail(_ reason: PlaybackFailure) {
        let reported = current
        teardownCurrentItem()
        session.deactivate()
        state = .failed(reason)
        pushNowPlaying()

        guard let reported, reported.kind == .station, let code = reason.reportCode else { return }
        let reporter = self.reporter
        Task.detached(priority: .background) {
            await reporter.reportDeadStream(stationID: reported.id, reason: code)
        }
    }

    private func teardownCurrentItem() {
        watchdog?.cancel()
        watchdog = nil

        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil

        itemObserver?.invalidate()
        itemObserver = nil
        rateObserver?.invalidate()
        rateObserver = nil

        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        failureObserver = nil

        if let metadataOutput, let playerItem = player?.currentItem {
            playerItem.remove(metadataOutput)
        }
        metadataOutput?.setDelegate(nil, queue: nil)
        metadataOutput = nil
        metadataForwarder = nil

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        pausedByInterruption = false
    }
}

/// `AVPlayerItemMetadataOutput` 은 `NSObject` 델리게이트를 요구한다.
///
/// 델리게이트 큐가 메인이라 여기서 곡명 문자열까지 뽑고,
/// 메인 액터로는 `String` 하나만 넘긴다.
private final class MetadataForwarder: NSObject, AVPlayerItemMetadataOutputPushDelegate, @unchecked Sendable {
    private weak var owner: AudioPlayerService?

    init(owner: AudioPlayerService) {
        self.owner = owner
    }

    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        // 델리게이트 큐를 메인으로 잡아뒀다. 여기서 문자열까지 뽑고 나면
        // AVFoundation 객체가 액터 경계를 넘을 일이 없다.
        //
        // `stringValue` 는 iOS 16 에서 deprecated 지만 여기서는 이게 맞다.
        // 밀어 넣어주는 타임드 메타데이터는 값이 이미 메모리에 있어서 비동기로 받을 것이 없고,
        // `load(.stringValue)` 를 쓰면 AVMetadataItem 배열이 액터를 넘어가
        // Swift 6 언어 모드에서 오류가 된다. 경고 하나를 남기는 쪽을 골랐다.
        let title = groups
            .flatMap(\.items)
            .lazy
            .compactMap { $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        guard let title else { return }
        MainActor.assumeIsolated {
            owner?.updateStreamTitle(title)
        }
    }
}
