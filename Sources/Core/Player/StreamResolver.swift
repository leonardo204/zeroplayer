import Foundation

/// 재생 직전에 스트림 주소를 알아내는 통로.
///
/// 주소를 앱에 담아두지 않기 위해 재생 코드는 이 프로토콜만 안다.
/// 구현은 `ProxyStreamResolver` 하나다. 주소는 재생 직전에만 받고 저장하지 않는다.
protocol StreamResolving: Sendable {
    func streamURL(for item: PlayableItem) async throws -> URL
}

enum StreamResolveError: Error, Equatable {
    case notFound(String)
}
