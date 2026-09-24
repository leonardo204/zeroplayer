import Foundation
import Observation
import os

/// 히든 라디오 화면이 보고 있는 상태.
///
/// 채널 목록은 캐시하지 않는다. 앱에 한국 지상파 흔적을 남기지 않는다는 것이
/// 이 기능의 전제라, 목록도 주소도 열려 있는 동안 메모리에만 둔다.
@MainActor
@Observable
final class HiddenModel {
    private(set) var channels: [HiddenChannelDTO] = []
    private(set) var isLoading = false
    private(set) var errorText: String?
    /// 채널 ID → 지금 방송 중인 프로그램. 못 읽은 채널은 값이 없다.
    private(set) var nowByChannel: [String: HiddenNowDTO] = [:]

    private let client: ProxyClienting
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "hidden")

    init(client: ProxyClienting = ProxyClient()) {
        self.client = client
    }

    func load(token: String) async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let list = try await client.hiddenChannels(token: token)
            channels = list.items
            log.info("채널 \(list.items.count)개")
        } catch {
            channels = []
            errorText = (error as? ProxyError)?.errorDescription ?? "채널 목록을 가져오지 못했습니다."
            return
        }

        await loadSchedules(token: token)
    }

    /// 편성표는 채널마다 방송사 페이지를 한 번씩 읽는다. 한 곳이 막혀도 나머지는 채운다.
    func loadSchedules(token: String) async {
        let targets = channels.filter(\.hasSchedule)
        guard !targets.isEmpty else { return }

        await withTaskGroup(of: (String, HiddenNowDTO?).self) { group in
            for channel in targets {
                group.addTask { [client] in
                    let now = try? await client.hiddenNow(channelID: channel.id, token: token)
                    return (channel.id, now)
                }
            }
            for await (id, now) in group {
                guard let now, !now.isEmpty else { continue }
                nowByChannel[id] = now
            }
        }
    }

    /// 재생 중인 채널의 프로그램만 다시 읽는다. 5분마다면 충분하다.
    func refreshNow(channelID: String, token: String) async {
        guard let now = try? await client.hiddenNow(channelID: channelID, token: token), !now.isEmpty else { return }
        nowByChannel[channelID] = now
    }

    func clear() {
        channels = []
        nowByChannel = [:]
        errorText = nil
    }
}
