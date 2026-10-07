import Foundation
import os

/// 알람 단추를 누른 뒤 무슨 일이 있었는지 기기에 남긴다.
///
/// 알람 인텐트는 앱 화면 없이 돌아서 케이블을 꽂지 않으면 로그를 볼 수 없다.
/// '방송 켜기' 뒤에 라디오가 끊기거나 알람이 다시 울리는 원인을 가리려고,
/// 연쇄 알람 치우기 결과와 오디오 인터럽트를 `Documents/alarm-log.txt` 에 적는다.
/// 기기 밖으로 보내지 않는다. 300줄을 넘으면 앞에서부터 버린다.
enum AlarmDiagnostics {
    private static let lock = NSLock()
    private static let maxLines = 300
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "alarm-diag")

    static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("alarm-log.txt")
    }

    static func write(_ message: String) {
        let stamp = ISO8601DateFormatter.string(
            from: Date(), timeZone: .current,
            formatOptions: [.withFullDate, .withFullTime, .withFractionalSeconds])
        let line = "\(stamp) \(message)"
        logger.info("\(line, privacy: .public)")
        lock.lock()
        defer { lock.unlock() }
        var lines = (try? String(contentsOf: fileURL, encoding: .utf8))?
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init) ?? []
        lines.append(line)
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
        try? (lines.joined(separator: "\n") + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
