import Foundation
import Observation

@MainActor
protocol AudioPlaying: AnyObject {
    var state: PlaybackState { get }
    var current: PlayableItem? { get }
    var elapsed: TimeInterval { get }

    func play(_ item: PlayableItem) async
    func pause()
    func resume()
    func stop()
    func next() async
    func previous() async
}

/// 앱에서 유일한 재생 주체.
///
/// M0 에서는 상태 기계만 있다. AVPlayer·AVAudioSession·MPNowPlayingInfoCenter 는
/// M1 에서 채운다. 화면은 지금부터 이 객체만 바라본다.
@MainActor
@Observable
final class AudioPlayerService: AudioPlaying {
    private(set) var state: PlaybackState = .idle
    private(set) var current: PlayableItem?
    private(set) var elapsed: TimeInterval = 0

    func play(_ item: PlayableItem) async {
        current = item
        state = .loading
        // M1: 프록시에서 스트림 URL 을 받아 AVPlayer 에 넣는다.
        state = .playing
        elapsed = 0
    }

    func pause() {
        guard state == .playing else { return }
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        state = .playing
    }

    func stop() {
        current = nil
        state = .idle
        elapsed = 0
    }

    func next() async {
        // M3: 프리셋의 다음 소스, 또는 추천 목록의 다음 항목.
    }

    func previous() async {
        // M3: 위와 같다.
    }
}
