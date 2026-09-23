import Foundation

enum PlaybackState: Equatable, Sendable {
    case idle
    case loading
    case playing
    case paused
    case failed(PlaybackFailure)

    var isActive: Bool {
        switch self {
        case .loading, .playing, .paused: return true
        case .idle, .failed: return false
        }
    }
}

enum PlaybackFailure: Equatable, Sendable {
    /// 15초 안에 첫 오디오가 오지 않았다. 프록시에 신고한다.
    case noAudio
    case network
    case unknown(String)

    /// 화면에 그대로 띄우는 문구다.
    var message: String {
        switch self {
        case .noAudio: return "방송이 응답하지 않습니다"
        case .network: return "연결하지 못했습니다"
        case .unknown: return "재생할 수 없습니다"
        }
    }
}
