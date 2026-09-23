import Foundation

/// M1 에서 재생 경로를 확인하려고 손으로 적어둔 방송국이다.
/// M2 에서 프록시가 목록과 주소를 모두 내려주면 이 파일과 `DemoStreamResolver` 를 지운다.
///
/// 마지막 항목만 평문 HTTP 다. `NSAllowsArbitraryLoadsForMedia` 예외가 실제로 먹는지
/// 확인하려고 남겨뒀다.
enum DemoStations {
    struct Entry {
        let item: PlayableItem
        let url: URL
    }

    static let all: [Entry] = [
        make(
            id: "demo.somafm.groovesalad",
            title: "Groove Salad",
            subtitle: "SomaFM · 다운템포",
            stream: "https://ice1.somafm.com/groovesalad-128-mp3"
        ),
        make(
            id: "demo.somafm.dronezone",
            title: "Drone Zone",
            subtitle: "SomaFM · 취침용 앰비언트",
            stream: "https://ice1.somafm.com/dronezone-128-mp3"
        ),
        make(
            id: "demo.radioparadise.main",
            title: "Radio Paradise",
            subtitle: "메인 믹스",
            stream: "https://stream.radioparadise.com/mp3-128"
        ),
        make(
            id: "demo.somafm.groovesalad.http",
            title: "Groove Salad (평문 HTTP)",
            subtitle: "ATS 예외 확인용",
            stream: "http://ice1.somafm.com/groovesalad-128-mp3"
        ),
        make(
            id: "demo.broken",
            title: "끊긴 주소",
            subtitle: "15초 실패 감지 확인용",
            stream: "https://ice1.somafm.com/this-stream-does-not-exist"
        ),
    ]

    static func streamURL(for id: String) -> URL? {
        all.first { $0.item.id == id }?.url
    }

    private static func make(id: String, title: String, subtitle: String, stream: String) -> Entry {
        guard let url = URL(string: stream) else {
            preconditionFailure("DemoStations 의 주소가 잘못됐다: \(stream)")
        }
        var item = PlayableItem(id: id, kind: .station, title: title)
        item.subtitle = subtitle
        return Entry(item: item, url: url)
    }
}
