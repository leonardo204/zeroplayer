import Foundation
import MediaPlayer

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
    }

    private let infoCenter = MPNowPlayingInfoCenter.default()
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

        // 라디오에는 구간 이동이 없다. M5 에서 팟캐스트를 붙일 때 되감기를 켠다.
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
    }

    /// 재생 중인 항목이 바뀌거나 곡명이 들어올 때마다 부른다.
    func update(item: PlayableItem?, streamTitle: String?, elapsed: TimeInterval, isPlaying: Bool) {
        guard let item else {
            infoCenter.nowPlayingInfo = nil
            infoCenter.playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: streamTitle ?? item.title,
            MPMediaItemPropertyArtist: streamTitle == nil ? (item.subtitle ?? "") : item.title,
            MPNowPlayingInfoPropertyIsLiveStream: item.isLive,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if !item.isLive {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        }

        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = isPlaying ? .playing : .paused
    }

    /// 라디오는 이전·다음이 프리셋 안에서만 뜻이 있다. M3 전까지는 꺼둔다.
    func setSkipEnabled(_ enabled: Bool) {
        commandCenter.nextTrackCommand.isEnabled = enabled
        commandCenter.previousTrackCommand.isEnabled = enabled
    }
}
