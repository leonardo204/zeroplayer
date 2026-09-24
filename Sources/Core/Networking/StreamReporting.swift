import Foundation

/// 재생이 실패했을 때 서버에 알리는 통로.
/// 재생 코드가 `ProxyClient` 전체를 알 필요는 없어서 이만큼만 떼어 놓는다.
protocol StreamReporting: Sendable {
    func reportDeadStream(stationID: String, reason: String) async
}
