import Foundation
import SwiftData
import os

/// 1.7 이 Documents 폴더에 남긴 JSON 두 개를 2.0 으로 옮긴다.
///
/// 번들 ID 가 같아서 업데이트하면 그 파일이 그대로 남아 있다. 옮기는 것은 두 가지다 —
/// 히든 해제 상태와 알람 하나. 유튜브 재생목록은 2.0 에 자리가 없어 버리고, 대신
/// 없어졌다는 안내를 한 번 띄운다(`docs/05-ads-policy.md` 1번).
///
/// 원본 파일은 지우지 않는다. 한 번 옮겼다는 표시만 남기고 다음부터 건너뛴다.
@MainActor
struct LegacyMigration {
    /// 한 번 옮겼는지. 값이 있으면 다시 돌지 않는다.
    static let doneKey = "zp.migration.v1.done"
    /// 유튜브 재생목록이 있었는지. 안내 화면을 한 번 띄우는 데 쓴다.
    static let hadYouTubeKey = "zp.migration.v1.hadYouTube"

    private let context: ModelContext
    private let defaults: UserDefaults
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "migration")

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
    }

    /// 결과를 돌려준다. 화면은 `hadYouTubePlaylists` 만 보고 안내를 띄운다.
    @discardableResult
    func run(hidden: HiddenAccess, alarms: AlarmStore) async -> Result {
        guard !defaults.bool(forKey: Self.doneKey) else {
            return Result(alreadyDone: true)
        }

        var result = Result(alreadyDone: false)
        let settings = Self.load(LegacySettings.self, from: "CRSettings.json")
        let channels = Self.load(LegacyChannels.self, from: "CRChannels.json")

        if settings == nil && channels == nil {
            // 1.7 을 쓴 적이 없는 새 설치다. 다시 찾지 않는다.
            defaults.set(true, forKey: Self.doneKey)
            return result
        }

        if let settings {
            if settings.isUnlocked, !hidden.isUnlocked {
                await unlockHidden(into: hidden)
                result.unlockedHidden = hidden.isUnlocked
            }
            if let alarm = settings.alarmInfo, alarm.isAlarmOn, alarms.all().isEmpty {
                await migrate(alarm, into: alarms)
                result.movedAlarm = true
            }
        }

        if let channels {
            let radios = channels.channels.filter { $0.type == 0 }
            result.movedFavorites = addFavorites(from: radios)
            result.hadYouTubePlaylists = channels.channels.contains { $0.type == 1 }
        }

        defaults.set(true, forKey: Self.doneKey)
        defaults.set(result.hadYouTubePlaylists, forKey: Self.hadYouTubeKey)
        log.info("""
            1.7 자료를 옮겼다 — 히든 \(result.unlockedHidden) · 알람 \(result.movedAlarm) \
            · 즐겨찾기 \(result.movedFavorites) · 유튜브 \(result.hadYouTubePlaylists)
            """)
        return result
    }

    struct Result {
        var alreadyDone: Bool
        var unlockedHidden = false
        var movedAlarm = false
        var movedFavorites = 0
        var hadYouTubePlaylists = false
    }

    // MARK: - 옮기는 것

    private func unlockHidden(into hidden: HiddenAccess) async {
        do {
            let unlocked = try await ProxyClient().unlockHidden()
            hidden.store(token: unlocked.token)
        } catch {
            // 다음 실행에서 다시 시도하지 않는다. 사용자가 12번 눌러 직접 열 수 있다.
            log.error("해제 토큰을 못 받았다: \(String(describing: error), privacy: .private)")
        }
    }

    private func migrate(_ legacy: LegacyAlarm, into alarms: AlarmStore) async {
        let alarm = AlarmSetting(
            hour: min(max(legacy.alarmHour, 0), 23),
            minute: min(max(legacy.alarmMin, 0), 59),
            weekdays: legacy.alarmDay?.weekdays ?? [],
            sourceKind: .auto,
            situation: .wake,
            label: "알람"
        )
        await alarms.add(alarm)
    }

    /// 1.7 채널 목록에 있던 지상파를 즐겨찾기로 옮긴다. 이름이 달라져서 표로 맞춘다.
    private func addFavorites(from radios: [LegacyChannel]) -> Int {
        var moved = 0
        for radio in radios {
            guard let id = Self.hiddenChannelID(for: radio.title) else { continue }
            let descriptor = FetchDescriptor<Favorite>(predicate: #Predicate { $0.itemID == id })
            if let existing = try? context.fetch(descriptor), !existing.isEmpty { continue }
            context.insert(Favorite(item: PlayableItem(
                id: id, kind: .hidden, title: radio.title, subtitle: "지상파"
            )))
            moved += 1
        }
        if moved > 0 { try? context.save() }
        return moved
    }

    /// 1.7 채널 이름 → 2.0 히든 채널 ID. 1.7 에 있던 14개를 그대로 옮긴다.
    ///
    /// AFN The Voice·Joe Radio·Legacy 는 방송이 없어져 2.0 에 없다(`CONTEXT.md` 6-10).
    /// 표에 없는 이름은 조용히 건너뛴다.
    static func hiddenChannelID(for legacyName: String) -> String? {
        let key = legacyName.lowercased().replacingOccurrences(of: " ", with: "")
        return [
            "kbsclassicfm": "kr:kbs-classicfm",
            "kbscoolfm": "kr:kbs-coolfm",
            "kbshappyfm": "kr:kbs-happyfm",
            "kbs1radio": "kr:kbs-1radio",
            "mbcfmforu": "kr:mbc-fm4u",
            "mbcstandardfm": "kr:mbc-standardfm",
            "sbspowerfm": "kr:sbs-powerfm",
            "sbslovefm": "kr:sbs-lovefm",
            "cbsmusic": "kr:cbs-musicfm",
            "tbsfm": "kr:tbs-fm",
            "afntheeagle": "kr:afn-eagle",
        ][key]
    }

    // MARK: - 읽기

    private static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let url = dir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - 1.7 이 남긴 모양

/// `CRSettings.json`. 1.7 의 `CRSettings` 와 같은 모양이되 전부 옵셔널로 받는다 —
/// 버전마다 칸이 조금씩 달라서 하나가 없다고 통째로 버리면 안 된다.
private struct LegacySettings: Decodable {
    let isUnlocked: Bool
    let alarmInfo: LegacyAlarm?

    enum CodingKeys: String, CodingKey { case isUnlocked, alarmInfo }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isUnlocked = (try? c.decode(Bool.self, forKey: .isUnlocked)) ?? false
        alarmInfo = try? c.decode(LegacyAlarm.self, forKey: .alarmInfo)
    }
}

private struct LegacyAlarm: Decodable {
    let isAlarmOn: Bool
    let alarmHour: Int
    let alarmMin: Int
    let alarmDay: LegacyAlarmDays?

    init(from decoder: Decoder) throws {
        enum K: String, CodingKey { case isAlarmOn, alarmHour, alarmMin, alarmDay }
        let c = try decoder.container(keyedBy: K.self)
        isAlarmOn = (try? c.decode(Bool.self, forKey: .isAlarmOn)) ?? false
        alarmHour = (try? c.decode(Int.self, forKey: .alarmHour)) ?? 7
        alarmMin = (try? c.decode(Int.self, forKey: .alarmMin)) ?? 0
        alarmDay = try? c.decode(LegacyAlarmDays.self, forKey: .alarmDay)
    }
}

private struct LegacyAlarmDays: Decodable {
    let mon, tue, wed, thu, fri, sat, sun: Bool

    /// 1=일 … 7=토 로 옮긴다. 하나도 안 켜져 있으면 빈 집합이고 다음 한 번만 울린다.
    var weekdays: Set<Int> {
        var days: Set<Int> = []
        if sun { days.insert(1) }
        if mon { days.insert(2) }
        if tue { days.insert(3) }
        if wed { days.insert(4) }
        if thu { days.insert(5) }
        if fri { days.insert(6) }
        if sat { days.insert(7) }
        return days
    }
}

/// `CRChannels.json`. `type` 이 0 이면 라디오, 1 이면 유튜브 재생목록이다.
private struct LegacyChannels: Decodable {
    let channels: [LegacyChannel]
}

private struct LegacyChannel: Decodable {
    let type: Int
    let title: String
}
