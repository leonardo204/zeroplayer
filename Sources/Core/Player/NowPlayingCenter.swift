import Foundation
import MediaPlayer
import UIKit

/// 잠금화면과 제어 센터에 보이는 정보, 그리고 거기서 오는 명령을 담당한다.
///
/// 명령 처리는 전부 `AudioPlayerService` 로 넘긴다. 이 객체는 재생을 직접 하지 않는다.
@MainActor
final class NowPlayingCenter {
    struct Commands {
        var play: () -> Void
        var pause: () -> Void
        var stop: () -> Void
        var next: () -> Void
        var previous: () -> Void
        var skipBackward: () -> Void
        var skipForward: () -> Void
        /// 잠금화면 진행 바를 끌었을 때 옮길 자리(초).
        var seek: (TimeInterval) -> Void
    }

    private let infoCenter = MPNowPlayingInfoCenter.default()
    /// 지금 잠금화면에 올려 둔 그림과 그 주소. 같은 주소를 다시 받지 않으려고 들고 있는다.
    private var shownArtworkURL: URL?
    private var cachedArtwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var isWired = false

    /// 앱 시작 때 한 번만 부른다. 두 번 불러도 핸들러가 겹치지 않는다.
    func wire(_ commands: Commands) {
        guard !isWired else { return }
        isWired = true

        commandCenter.playCommand.addTarget { _ in
            MainActor.assumeIsolated { commands.play() }
            return .success
        }
        commandCenter.pauseCommand.addTarget { _ in
            MainActor.assumeIsolated { commands.pause() }
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            MainActor.assumeIsolated { commands.play() }
            return .success
        }
        commandCenter.stopCommand.addTarget { _ in
            MainActor.assumeIsolated { commands.stop() }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { _ in
            MainActor.assumeIsolated { commands.next() }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { _ in
            MainActor.assumeIsolated { commands.previous() }
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipBackwardCommand.addTarget { _ in
            MainActor.assumeIsolated { commands.skipBackward() }
            return .success
        }
        commandCenter.skipForwardCommand.addTarget { _ in
            MainActor.assumeIsolated { commands.skipForward() }
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let target = event.positionTime
            MainActor.assumeIsolated { commands.seek(target) }
            return .success
        }

        // 라디오에는 옮길 자리가 없다. 에피소드가 준비되면 켠다.
        setScrubEnabled(false)
    }

    /// 구간 이동·되감기 단추를 켜고 끈다. 에피소드일 때만 켠다.
    func setScrubEnabled(_ enabled: Bool) {
        commandCenter.changePlaybackPositionCommand.isEnabled = enabled
        commandCenter.skipForwardCommand.isEnabled = enabled
        commandCenter.skipBackwardCommand.isEnabled = enabled
    }

    /// 재생 중인 항목이 바뀌거나 곡명이 들어올 때마다 부른다.
    func update(
        item: PlayableItem?,
        streamTitle: String?,
        artworkURL: URL? = nil,
        elapsed: TimeInterval,
        duration: TimeInterval = 0,
        rate: Double = 1.0,
        isPlaying: Bool
    ) {
        guard let item else {
            infoCenter.nowPlayingInfo = nil
            setScrubEnabled(false)
            artworkTask?.cancel()
            artworkTask = nil
            shownArtworkURL = nil
            cachedArtwork = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: streamTitle ?? item.title,
            MPMediaItemPropertyArtist: streamTitle == nil ? (item.subtitle ?? "") : item.title,
            MPNowPlayingInfoPropertyIsLiveStream: item.isLive,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: rate,
        ]
        if !item.isLive {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
            if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        }

        // 같은 그림을 다시 받지 않는다. 곡이 바뀔 때마다 갱신이 여러 번 온다.
        if let cachedArtwork, shownArtworkURL == artworkURL {
            info[MPMediaItemPropertyArtwork] = cachedArtwork
        }

        // `playbackState` 는 설정하지 않는다. iOS 에서는
        // `com.apple.mediaremote.set-playback-state` 엔타이틀먼트가 있는 앱만 쓸 수 있고,
        // 없으면 시스템이 무시하면서 로그에 경고만 남긴다. 재생 여부는 위의
        // `MPNowPlayingInfoPropertyPlaybackRate` 로 이미 전달된다.
        infoCenter.nowPlayingInfo = info

        if shownArtworkURL != artworkURL {
            loadArtwork(artworkURL)
        }
    }

    // MARK: - 잠금화면 그림

    /// 그림은 따로 받아서 나중에 얹는다. 글자가 먼저 떠야 화면이 비어 보이지 않는다.
    private func loadArtwork(_ url: URL?) {
        artworkTask?.cancel()
        shownArtworkURL = url
        cachedArtwork = nil
        guard let url else { return }

        artworkTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  !Task.isCancelled
            else { return }

            await MainActor.run { [weak self] in
                guard let self, self.shownArtworkURL == url else { return }
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.cachedArtwork = artwork
                var info = self.infoCenter.nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = artwork
                self.infoCenter.nowPlayingInfo = info
            }
        }
    }

    /// 라디오는 이전·다음이 프리셋 안에서만 뜻이 있다. M3 전까지는 꺼둔다.
    func setSkipEnabled(_ enabled: Bool) {
        commandCenter.nextTrackCommand.isEnabled = enabled
        commandCenter.previousTrackCommand.isEnabled = enabled
    }
}
