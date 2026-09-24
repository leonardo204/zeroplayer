import Foundation

/// 재생 직전에 스트림 주소를 알아내는 통로.
///
/// 주소를 앱에 담아두지 않기 위해 재생 코드는 이 프로토콜만 안다.
/// 구현은 `ProxyStreamResolver` 하나다. 주소는 재생 직전에만 받고 저장하지 않는다.
protocol StreamResolving: Sendable {
    /// `hiddenToken` 은 한국 지상파에만 쓴다. 공개 채널에는 실어 보내지 않는다.
    func streamURL(for item: PlayableItem, hiddenToken: String?) async throws -> URL
}

enum StreamResolveError: Error, Equatable {
    case notFound(String)
    /// 히든 채널인데 해제 토큰이 없다. 해제가 풀렸거나 기기를 바꾼 경우다.
    case locked
}
