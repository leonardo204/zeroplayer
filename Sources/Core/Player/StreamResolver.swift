import Foundation

/// 재생 직전에 스트림 주소를 알아내는 통로.
///
/// 주소를 앱에 담아두지 않기 위해 재생 코드는 이 프로토콜만 안다.
/// M1 에서는 하드코딩한 표(`DemoStreamResolver`)를 쓰고,
/// M2 에서 `ai.zerolive.co.kr` 를 부르는 구현으로 갈아 끼운다.
protocol StreamResolving: Sendable {
    func streamURL(for item: PlayableItem) async throws -> URL
}

enum StreamResolveError: Error, Equatable {
    case notFound(String)
}

/// M1 전용. M2 에서 `DemoStations.swift` 와 함께 지운다.
struct DemoStreamResolver: StreamResolving {
    func streamURL(for item: PlayableItem) async throws -> URL {
        guard let url = DemoStations.streamURL(for: item.id) else {
            throw StreamResolveError.notFound(item.id)
        }
        return url
    }
}
