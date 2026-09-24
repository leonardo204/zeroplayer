import Foundation

/// 재생 직전에 프록시에 주소를 묻는다. 받은 주소는 어디에도 저장하지 않는다.
struct ProxyStreamResolver: StreamResolving {
    let client: ProxyClienting

    init(client: ProxyClienting = ProxyClient()) {
        self.client = client
    }

    func streamURL(for item: PlayableItem, hiddenToken: String?) async throws -> URL {
        let dto: StreamDTO
        switch item.kind {
        case .podcast:
            dto = try await client.episodeStream(episodeID: item.id)
        case .hidden:
            guard let hiddenToken else { throw StreamResolveError.locked }
            dto = try await client.hiddenStreamURL(channelID: item.id, token: hiddenToken)
        case .station:
            dto = try await client.streamURL(stationID: item.id)
        }
        guard let url = URL(string: dto.url) else {
            throw StreamResolveError.notFound(item.id)
        }
        return url
    }
}
