import Foundation

enum SourceKind: String, Codable, Sendable {
    case station     // 인터넷 라디오
    case podcast     // 팟캐스트 에피소드
    case hidden      // 한국 지상파 (히든)
}

/// 재생 대상을 하나로 감싼다. 재생 코드는 종류를 구분하지 않는다.
struct PlayableItem: Identifiable, Hashable, Sendable {
    let id: String
    let kind: SourceKind
    let title: String
    var subtitle: String?
    var artworkURL: URL?
    /// 에피소드 길이. 라디오는 길이가 없어서 nil 이다.
    var durationSeconds: TimeInterval?
    /// 에피소드가 속한 팟캐스트. 기록과 화면 표시에 쓴다.
    var feedID: String?

    /// 길이가 없는 소스인지. 라디오는 진행 바 대신 경과 시간만 쓴다.
    var isLive: Bool { kind != .podcast }
}
