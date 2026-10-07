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
    /// 지금 보여 줄 썸네일. 목록에서 온 것으로 시작해 곡·프로그램 그림이 오면 바뀐다.
    var artworkURL: URL? { get }
    /// 에피소드 길이. 라디오는 0 이다.
    var duration: TimeInterval { get }

    func play(_ item: PlayableItem, origin: PlaybackOrigin) async
    func pause()
    func resume() async
    func stop()
    func next() async
    func previous() async
    /// 자동 선택이 고른 후보 줄. 다음 후보로 넘어갈 때 쓴다.
    func setQueue(_ items: [PlayableItem], origin: PlaybackOrigin)
    /// 자동 선택이 걸러야 할 방송국 번호.
    var excludedStationIDs: Set<String> { get }
    /// 넘어갈 후보가 남아 있는지.
    var hasNextInQueue: Bool { get }
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
    /// 화면이 보는 단 하나의 썸네일 값.
    ///
    /// 목록에서 받은 주소로 시작한다. 재생이 붙은 뒤 ICY 가 곡 이미지를 주거나
    /// 지상파 편성표가 프로그램 이미지를 주면 그쪽으로 바꾼다.
    private(set) var artworkURL: URL?
    /// 에피소드 길이. 라디오는 0 으로 둔다.
    private(set) var duration: TimeInterval = 0
    /// 재생 속도. 에피소드에만 쓴다. 고른 값은 다음 재생에도 이어진다.
    private(set) var playbackRate: Double = UserDefaults.standard.double(forKey: "zp.podcast.rate") > 0
        ? UserDefaults.standard.double(forKey: "zp.podcast.rate")
        : 1.0

    /// 첫 오디오를 이 시간 안에 못 받으면 실패로 본다.
    static let firstAudioTimeout: Duration = .seconds(15)

    /// 자동 종료 타이머. 앱에 하나뿐이라 여기 둔다.
    let sleepTimer = SleepTimer()

    /// 썸네일을 채우고 편성표를 새로 받는 일. 항목이 바뀌면 취소한다.
    @ObservationIgnored private var artworkTask: Task<Void, Never>?

    @ObservationIgnored private let resolver: StreamResolving
    @ObservationIgnored private let reporter: StreamReporting
    /// 썸네일과 편성표를 뒤에서 채울 때만 쓴다. 재생 경로는 `resolver` 를 지난다.
    @ObservationIgnored private let client: ProxyClienting
    @ObservationIgnored private weak var recorder: (any ListeningRecording)?
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
    /// 인터럽트가 시작된 시각. 오래 끊겼으면 스트림을 새로 연다.
    @ObservationIgnored private var interruptedAt: Date?
    /// 첫 소리가 나기 전에 끊겼는지. 이때는 이어 트는 게 아니라 처음부터 다시 건다.
    @ObservationIgnored private var interruptedWhileLoading = false
    /// 이보다 오래 끊겼으면 라이브 스트림은 이어 붙지 않는다. 연결을 새로 만든다.
    static let liveReconnectThreshold: TimeInterval = 60
    /// 지금 재생이 어디서 시작됐는지. 청취 기록에 그대로 들어간다.
    @ObservationIgnored private var origin: PlaybackOrigin = .manual
    @ObservationIgnored private var isSessionOpen = false
    /// 듣던 위치를 남길 곳. 에피소드에만 쓴다.
    @ObservationIgnored private var positions: (any PlaybackPositionKeeping)?
    /// 히든 해제 상태. 한국 지상파 주소를 물을 때만 토큰을 꺼내 쓴다.
    @ObservationIgnored private weak var hidden: HiddenAccess?
    /// 자동 선택에서 뺀 방송국. '그만 듣기' 가 여기에 담고 대기열이 여기를 걸러 본다.
    @ObservationIgnored private weak var excluded: (any StationExcluding)?
    /// 자동 선택이 고른 후보 줄. '그만 듣기' 를 눌렀을 때 다음으로 넘어갈 자리다.
    ///
    /// 목록에서 직접 눌러 튼 경우에는 비어 있다. 그때 '그만 듣기' 는 제외만 하고 멈춘다 —
    /// 사람이 고른 자리에서 앱이 제멋대로 다음 방송을 트는 것은 놀랍다.
    ///
    /// 관찰 대상으로 둔다. 화면의 '다음' 단추가 이 값으로 켜지고 꺼진다.
    private var queue: [PlayableItem] = []
    /// 준비되면 이 위치로 옮긴다. 이어듣기 값이다.
    @ObservationIgnored private var pendingSeek: TimeInterval?
    @ObservationIgnored private var lastSavedPosition: TimeInterval = 0
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    /// 되감기·건너뛰기 폭. 잠금화면 단추와 화면 단추가 같은 값을 쓴다.
    static let skipBackSeconds: TimeInterval = 15
    static let skipForwardSeconds: TimeInterval = 30
    static let rateChoices: [Double] = [1.0, 1.2, 1.5, 2.0]

    init(
        resolver: StreamResolving = ProxyStreamResolver(),
        reporter: StreamReporting = ProxyClient(),
        client: ProxyClienting = ProxyClient()
    ) {
        self.resolver = resolver
        self.reporter = reporter
        self.client = client
        wireSession()
        wireRemoteCommands()
        wireSleepTimer()
    }

    /// 청취 기록을 남길 곳을 꽂는다. 앱이 뜰 때 한 번만 부른다.
    func attach(recorder: any ListeningRecording) {
        self.recorder = recorder
    }

    /// 듣던 위치를 남길 곳을 꽂는다. 앱이 뜰 때 한 번만 부른다.
    func attach(positions: any PlaybackPositionKeeping) {
        self.positions = positions
    }

    /// 히든 해제 상태를 꽂는다. 앱이 뜰 때 한 번만 부른다.
    func attach(hidden: HiddenAccess) {
        self.hidden = hidden
    }

    /// 제외 목록을 꽂는다. 앱이 뜰 때 한 번만 부른다.
    func attach(excluded: any StationExcluding) {
        self.excluded = excluded
    }

    /// 자동 선택이 걸러야 할 방송국 번호. 후보를 고르는 쪽이 읽는다.
    ///
    /// 후보를 고르는 곳이 셋(프리셋·알람·추천)인데 저장소를 세 군데에 따로 꽂으면
    /// 한 곳을 빼먹는다. 재생기가 이미 들고 있으니 여기로 물어보게 한다.
    var excludedStationIDs: Set<String> { excluded?.excludedIDs ?? [] }

    // MARK: - 재생 조작

    func play(_ item: PlayableItem, origin: PlaybackOrigin = .manual) async {
        closeListeningSession()
        teardownCurrentItem()

        self.origin = origin
        // 대기열에 없는 것을 틀었다는 것은 사람이 목록에서 직접 골랐다는 뜻이다.
        // 그때는 지난 자동 선택 줄을 버린다 — 안 버리면 '그만 듣기' 가 엉뚱한
        // 방송으로 넘어간다.
        if !queue.contains(where: { $0.id == item.id }) { queue = [] }
        current = item
        streamTitle = nil
        artworkURL = item.artworkURL
        duration = item.durationSeconds ?? 0
        // 에피소드는 듣던 자리에서 잇는다. 준비되면 이 값으로 옮긴다.
        pendingSeek = item.kind == .podcast ? positions?.position(for: item.id) : nil
        lastSavedPosition = 0
        elapsed = 0
        liveAccumulated = 0
        liveStartedAt = nil
        pausedByInterruption = false
        interruptedWhileLoading = false
        interruptedAt = nil
        state = .loading
        pushNowPlaying()

        let url: URL
        do {
            url = try await resolver.streamURL(for: item, hiddenToken: hidden?.token)
        } catch {
            log.error("스트림 주소를 못 받았다: \(String(describing: error))")
            fail(.network)
            return
        }

        // 화면을 오래 누르고 있다가 다른 항목으로 넘어갔으면 여기서 버린다.
        guard current?.id == item.id else { return }

        do {
            try await session.activate()
        } catch {
            log.error("오디오 세션을 못 켰다: \(String(describing: error))")
            fail(.unknown("audio session"))
            return
        }

        // 세션을 켜는 사이에 다른 항목으로 넘어갔을 수 있다. 이제는 await 가 하나 더 있다.
        guard current?.id == item.id else { return }

        log.info("재생 시도: \(url.absoluteString, privacy: .public)")
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        // 라이브는 앞부분을 받아둬도 쓸모가 없다. 시작을 앞당기는 쪽으로 둔다.
        playerItem.preferredForwardBufferDuration = item.isLive ? 3 : 0

        attachMetadataOutput(to: playerItem)
        observe(playerItem)

        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        // `play()` 는 재생 속도를 1 로 되돌린다. 기본 속도를 정해 두면 그 값으로 시작한다.
        player.defaultRate = item.kind == .podcast ? Float(playbackRate) : 1
        // 지난 재생이 페이드아웃 중에 끝났을 수 있다. 볼륨은 항상 1 에서 시작한다.
        player.volume = 1
        observeRate(of: player)
        observeTime(of: player)
        self.player = player

        startArtworkWork(for: item)
        startWatchdog(for: item.id)
        player.play()
    }

    func pause() {
        guard state == .playing else { return }
        player?.pause()
        savePosition(force: true)
        accumulateLiveElapsed()
        pausedByInterruption = false
        interruptedWhileLoading = false
        interruptedAt = nil
        state = .paused
        pushNowPlaying()
    }

    func resume() async {
        guard state == .paused, let player else { return }
        do {
            try await session.activate()
        } catch {
            log.error("재개할 때 오디오 세션을 못 켰다: \(String(describing: error))")
            fail(.unknown("audio session"))
            return
        }
        // 세션을 켜는 사이에 사용자가 정지했거나 다른 것을 틀었을 수 있다.
        guard state == .paused, self.player === player else { return }
        liveStartedAt = Date()
        player.play()
        state = .playing
        pushNowPlaying()
    }

    func stop() {
        savePosition(force: true)
        closeListeningSession()
        queue = []
        sleepTimer.reset()
        teardownCurrentItem()
        session.deactivate()
        current = nil
        streamTitle = nil
        artworkURL = nil
        state = .idle
        elapsed = 0
        duration = 0
        liveAccumulated = 0
        liveStartedAt = nil
        pushNowPlaying()
    }

    /// 실패한 뒤 사용자가 다시 시도할 때 쓴다.
#if DEBUG
    /// 시뮬레이터에서 화면 배치만 확인하려고 둔 통로다.
    /// 시뮬레이터는 실제 재생이 죽어서 미니 플레이어를 띄울 방법이 없다.
    /// `-ZPFakeNowPlaying 1` 로 켠다. 릴리스 빌드에는 들어가지 않는다.
    func debugShowFakeItem() {
        current = PlayableItem(
            id: "debug.fake",
            kind: .station,
            title: "확인용 방송",
            subtitle: "미니 플레이어 자리 확인",
            artworkURL: UserDefaults.standard.string(forKey: "ZPFakeArtwork").flatMap(URL.init(string:))
        )
        artworkURL = current?.artworkURL
        state = .paused
        elapsed = 0
    }
#endif

    func retry() async {
        guard let item = current else { return }
        await play(item, origin: origin)
    }

    // MARK: - 자동 종료 타이머

    func startSleepTimer(minutes: Int, fadeOutSeconds: Int) {
        sleepTimer.start(minutes: minutes, fadeOutSeconds: fadeOutSeconds)
    }

    func cancelSleepTimer() {
        sleepTimer.cancel()
    }

    private func wireSleepTimer() {
        sleepTimer.onVolume = { [weak self] volume in
            self?.player?.volume = volume
        }
        sleepTimer.onFinish = { [weak self] in
            guard let self else { return }
            self.log.info("자동 종료 타이머가 끝나 재생을 멈춘다")
            self.stop()
        }
    }

    // MARK: - 에피소드 조작

    /// 진행 바를 끌었을 때. 라디오에는 옮길 자리가 없다.
    func seek(to seconds: TimeInterval) {
        guard let player, let item = current, item.kind == .podcast else { return }
        let target = max(0, duration > 0 ? min(seconds, duration - 1) : seconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        elapsed = target
        lastSavedPosition = target
        pushNowPlaying()
    }

    func skip(by delta: TimeInterval) {
        guard current?.kind == .podcast else { return }
        seek(to: elapsed + delta)
    }

    func setRate(_ rate: Double) {
        playbackRate = rate
        UserDefaults.standard.set(rate, forKey: "zp.podcast.rate")
        guard let player, current?.kind == .podcast else { return }
        player.defaultRate = Float(rate)
        if state == .playing { player.rate = Float(rate) }
        pushNowPlaying()
    }

    // MARK: - 자동 선택 대기열

    /// 자동 선택이 고른 후보 줄을 넘겨받는다. 지금 트는 것도 여기에 들어 있어야 한다.
    func setQueue(_ items: [PlayableItem], origin: PlaybackOrigin) {
        queue = items
        self.origin = origin
    }

    /// 대기열에서 지금 것 다음에 오는 후보들. 제외된 것과 지금 것은 뺀다.
    private func upcoming() -> [PlayableItem] {
        let skip = excluded?.excludedIDs ?? []
        guard let currentID = current?.id, let at = queue.firstIndex(where: { $0.id == currentID })
        else { return queue.filter { !skip.contains($0.id) } }
        return queue[(at + 1)...].filter { !skip.contains($0.id) }
    }

    /// 넘어갈 후보가 남아 있는지. 화면의 '다음' 단추가 이 값을 본다.
    var hasNextInQueue: Bool { !upcoming().isEmpty }

    /// 대기열의 다음 후보로 넘어간다. 실제로 소리가 난 것을 돌려준다.
    @discardableResult
    func playNextInQueue() async -> PlayableItem? {
        let list = upcoming()
        guard !list.isEmpty else { return nil }

        let origin = self.origin
        for item in list.prefix(Self.autoAttempts) {
            await play(item, origin: origin)
            if await waitUntilAudible() {
                log.info("다음 후보로 넘어갔다: \(item.title, privacy: .public)")
                return item
            }
            log.info("응답하지 않아 다음 후보로 넘어간다: \(item.title, privacy: .public)")
        }
        return nil
    }

    /// '그만 듣기'. 지금 트는 방송을 자동 선택에서 빼고 다음 후보로 넘어간다.
    ///
    /// 돌려주는 값이 nil 이면 넘어갈 후보가 없었다는 뜻이다 — 그때는 멈춘다.
    /// 뺀 것만 하고 계속 틀어 두면 사용자는 아무 일도 안 일어난 줄 안다.
    @discardableResult
    func excludeCurrentAndAdvance() async -> PlayableItem? {
        guard let item = current, item.kind == .station else { return nil }
        excluded?.exclude(item)

        guard let played = await playNextInQueue() else {
            log.info("넘어갈 후보가 없어 멈춘다")
            stop()
            return nil
        }
        return played
    }

    /// 몇 번까지 다음 후보를 눌러 보는지. 죽은 방송이 이어지면 여기서 끊는다.
    private static let autoAttempts = 4

    /// `.loading` 을 벗어날 때까지 기다린다. 소리가 나기 시작하면 true.
    private func waitUntilAudible(timeout: Duration = .seconds(20)) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            switch state {
            case .loading:
                try? await Task.sleep(for: .milliseconds(100))
            case .playing, .paused:
                return true
            case .failed, .idle:
                return false
            }
        }
        return false
    }

    func next() async {
        await playNextInQueue()
    }

    func previous() async {
        // 자동 선택은 앞으로만 간다. 뒤로 가려면 목록에서 다시 누른다.
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
                    self.applyReadyState()
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleReachedEnd() }
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
                openListeningSession()
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
            savePosition(force: false)
        }
        recorder?.progress(elapsed)
    }

    /// 준비된 뒤에 한 번 돈다. 길이를 확정하고 듣던 자리로 옮긴다.
    private func applyReadyState() {
        guard let player, let item = current, item.kind == .podcast else { return }
        let itemDuration = CMTimeGetSeconds(player.currentItem?.duration ?? .indefinite)
        if itemDuration.isFinite, itemDuration > 0 { duration = itemDuration }

        if let target = pendingSeek {
            pendingSeek = nil
            log.info("듣던 자리에서 잇는다: \(Int(target))초")
            seek(to: target)
        }
        player.defaultRate = Float(playbackRate)
        if state == .playing { player.rate = Float(playbackRate) }
        nowPlaying.setScrubEnabled(true)
        pushNowPlaying()
    }

    /// 에피소드를 끝까지 들었다. 이어듣기 자리를 지우고 멈춘다.
    private func handleReachedEnd() {
        guard let item = current else { return }
        log.info("끝까지 재생했다: \(item.title, privacy: .public)")
        if item.kind == .podcast { positions?.clear(itemID: item.id) }
        closeListeningSession()
        player?.pause()
        state = .paused
        elapsed = duration
        pushNowPlaying()
    }

    /// 듣던 위치를 남긴다. 5초마다 한 번, 멈출 때는 바로.
    private func savePosition(force: Bool) {
        guard let item = current, item.kind == .podcast, elapsed > 0 else { return }
        guard force || abs(elapsed - lastSavedPosition) >= 5 else { return }
        lastSavedPosition = elapsed
        positions?.save(item: item, seconds: elapsed, duration: duration)
    }

    // MARK: - 청취 기록

    private func openListeningSession() {
        guard !isSessionOpen, let item = current else { return }
        recorder?.begin(item: item, origin: origin)
        isSessionOpen = true
    }

    private func closeListeningSession() {
        guard isSessionOpen else { return }
        isSessionOpen = false
        recorder?.finish(elapsed)
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

    // MARK: - 썸네일 채우기

    /// 재생을 걸어 둔 뒤 뒤에서 썸네일을 채운다. 재생 시작을 늦추지 않는다.
    ///
    /// - 지상파는 편성표에서 지금 방송 중인 프로그램의 이름과 그림을 받아 온다.
    ///   프로그램이 바뀔 때가 되면 서버가 알려 준 주기에 맞춰 다시 받는다.
    /// - 방송국은 목록을 거치지 않고 튼 경우(프리셋·알람)에만 낱개로 물어본다.
    private func startArtworkWork(for item: PlayableItem) {
        artworkTask?.cancel()
        guard item.kind == .hidden || (item.kind == .station && item.artworkURL == nil) else {
            artworkTask = nil
            return
        }

        artworkTask = Task { [weak self] in
            guard let self else { return }

            if item.kind == .station {
                if let dto = try? await self.client.station(id: item.id),
                   let url = dto.artworkURL.flatMap(URL.init(string:)),
                   !Task.isCancelled, self.current?.id == item.id {
                    self.artworkURL = url
                    self.pushNowPlaying()
                }
                return
            }

            guard let token = self.hidden?.token else { return }
            while !Task.isCancelled, self.current?.id == item.id {
                var wait = 300
                if let now = try? await self.client.hiddenNow(channelID: item.id, token: token) {
                    guard !Task.isCancelled, self.current?.id == item.id else { return }
                    // 같은 값이면 잠금화면을 다시 쓰지 않는다. 다시 쓸 때마다 차량 화면이
                    // 새 곡이 걸린 것처럼 갱신된다(2026-10-07 블루투스 실사용에서 겪었다).
                    var changed = false
                    if let name = now.programName, !name.isEmpty, name != self.streamTitle {
                        self.streamTitle = name
                        changed = true
                    }
                    if let url = now.artworkURL.flatMap(URL.init(string:)), url != self.artworkURL {
                        self.artworkURL = url
                        changed = true
                    }
                    if changed { self.pushNowPlaying() }
                    wait = max(60, min(now.refreshAfter, 1800))
                }
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    /// ICY 가 곡 이미지를 함께 줄 때가 있다(Radio Paradise 등).
    ///
    /// 평문 HTTP 로 오는 주소가 많은데 `AsyncImage` 는 ATS 에 막히므로 올려서 쓴다.
    fileprivate func updateStreamArtwork(_ raw: String) {
        let secure = raw.hasPrefix("http://")
            ? "https://" + raw.dropFirst("http://".count)
            : raw
        guard let url = URL(string: secure), url != artworkURL else { return }
        artworkURL = url
        pushNowPlaying()
    }

    /// `MetadataForwarder` 가 문자열만 뽑아 넘겨준다.
    fileprivate func updateStreamTitle(_ title: String) {
        // 지상파는 편성표의 프로그램 이름이 제목이다. 스트림이 함께 보내는 타임드
        // 메타데이터는 곡명이 아니라 `{"mediaTime":"…"}` 같은 기계용 값이라, 받아 쓰면
        // 몇 초마다 제목이 그 문자열로 바뀌고 차량 화면이 새 채널처럼 깜빡인다.
        guard current?.kind != .hidden else { return }
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
                AlarmDiagnostics.write("오디오 인터럽트 시작 state=\(self.state) item=\(self.current?.title ?? "-")")
                switch self.state {
                case .playing:
                    self.player?.pause()
                    self.accumulateLiveElapsed()
                    self.state = .paused
                    self.pausedByInterruption = true
                    self.interruptedAt = Date()
                    self.pushNowPlaying()
                case .loading:
                    // 첫 소리가 나기 전에 전화가 왔다. 그냥 두면 15초 워치독이 멀쩡한
                    // 방송을 죽은 것으로 보고 서버에 신고한다(`fail(.noAudio)`).
                    self.player?.pause()
                    self.watchdog?.cancel()
                    self.watchdog = nil
                    self.pausedByInterruption = true
                    self.interruptedWhileLoading = true
                    self.interruptedAt = Date()
                default:
                    break
                }
            case .ended(let shouldResume):
                AlarmDiagnostics.write("오디오 인터럽트 끝 shouldResume=\(shouldResume) paused=\(self.pausedByInterruption)")
                guard self.pausedByInterruption else { return }
                self.pausedByInterruption = false
                let wasLoading = self.interruptedWhileLoading
                let silence = self.interruptedAt.map { Date().timeIntervalSince($0) } ?? 0
                self.interruptedWhileLoading = false
                self.interruptedAt = nil
                guard shouldResume, let item = self.current else { return }

                // 라이브 스트림은 오래 끊기면 서버가 연결을 놓아 버린다. 기존
                // `AVPlayer` 에 play() 만 부르면 붙지 않고, 그 실패가 다시 방송국
                // 신고로 이어진다. 그래서 오래 끊겼으면 처음부터 새로 건다.
                let needsFresh = wasLoading
                    || (item.isLive && silence >= Self.liveReconnectThreshold)
                let origin = self.origin
                if needsFresh {
                    self.log.info("인터럽트가 \(Int(silence))초라 스트림을 새로 연다")
                    Task { await self.play(item, origin: origin) }
                } else {
                    Task { await self.resume() }
                }
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
                if self.state == .paused {
                    Task { await self.resume() }
                } else if self.state == .playing {
                    self.pause()
                }
            },
            pause: { [weak self] in self?.pause() },
            stop: { [weak self] in self?.stop() },
            next: { [weak self] in Task { await self?.next() } },
            previous: { [weak self] in Task { await self?.previous() } },
            skipBackward: { [weak self] in self?.skip(by: -Self.skipBackSeconds) },
            skipForward: { [weak self] in self?.skip(by: Self.skipForwardSeconds) },
            seek: { [weak self] seconds in self?.seek(to: seconds) }
        ))
        nowPlaying.setSkipEnabled(false)
    }

    private func pushNowPlaying() {
        nowPlaying.update(
            item: current,
            streamTitle: streamTitle,
            artworkURL: artworkURL,
            elapsed: elapsed,
            duration: duration,
            rate: current?.kind == .podcast ? playbackRate : 1.0,
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
        AlarmDiagnostics.write("재생 실패 \(reason) item=\(current?.title ?? "-")")
        let reported = current
        closeListeningSession()
        sleepTimer.reset()
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
        artworkTask?.cancel()
        artworkTask = nil
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

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil

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
        let values = groups
            .flatMap(\.items)
            .compactMap { $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 한 묶음에 곡명과 앨범 이미지 주소가 함께 오는 방송국이 있다
        // (Radio Paradise 가 그렇다). 주소로 보이는 것은 곡명으로 세우지 않는다.
        let title = values.first { !Self.looksLikeImageURL($0) && !Self.looksLikeMachineValue($0) }
        let artwork = values.first { Self.looksLikeImageURL($0) }

        guard title != nil || artwork != nil else { return }
        MainActor.assumeIsolated {
            if let title { owner?.updateStreamTitle(title) }
            if let artwork { owner?.updateStreamArtwork(artwork) }
        }
    }

    /// 사람이 읽을 곡명이 아닌 값. HLS 방송(SBS 등)은 ID3 로 `{"mediaTime":"…"}` 같은
    /// JSON 이나 시각 문자열을 몇 초마다 보낸다. 이것을 곡명으로 세우면 안 된다.
    private static func looksLikeMachineValue(_ value: String) -> Bool {
        if value.hasPrefix("{") || value.hasPrefix("[") { return true }
        if value.hasPrefix("http://") || value.hasPrefix("https://") { return true }
        // 2026-10-03T05:41:06.030Z 같은 시각만 있는 값
        if value.range(of: #"^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private static func looksLikeImageURL(_ value: String) -> Bool {
        guard value.hasPrefix("http://") || value.hasPrefix("https://") else { return false }
        let path = URL(string: value)?.path.lowercased() ?? value.lowercased()
        return [".jpg", ".jpeg", ".png", ".webp", ".gif"].contains { path.hasSuffix($0) }
    }
}
