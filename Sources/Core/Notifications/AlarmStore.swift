import Foundation
import SwiftData
import os

/// 알람을 기기에 쓰고 서버에도 밀어 넣는다.
///
/// 기기가 기준이다. 서버에 못 닿아도 알람은 만들어지고 로컬 백업이 울린다.
/// 서버에 못 넘긴 변경은 `needsSync` 로 표시해 뒀다가 다음에 앱을 열 때 다시 밀어 넣는다.
@MainActor
final class AlarmStore {
    private let context: ModelContext
    private let client: ProxyClienting
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "alarm")

    /// 서버에 밀어 넣는 중인 알람.
    ///
    /// `AlarmStore` 는 화면마다 새로 만들어 쓰므로 인스턴스 변수로는 막지 못한다.
    /// 이 자리가 없으면 알람을 만든 직후에 `syncAll()` 이 같은 알람을 한 번 더 올려
    /// 서버에 같은 알람이 두 줄 생긴다(실제로 그랬다).
    private static var inFlight: Set<UUID> = []

    init(context: ModelContext, client: ProxyClienting = ProxyClient()) {
        self.context = context
        self.client = client
    }

    func all() -> [AlarmSetting] {
        let descriptor = FetchDescriptor<AlarmSetting>(
            sortBy: [SortDescriptor(\.hour), SortDescriptor(\.minute)])
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 쓰기

    func add(_ alarm: AlarmSetting) async {
        context.insert(alarm)
        save()
        await push(alarm)
        await rescheduleLocal()
    }

    /// 화면이 값을 바꾼 뒤 부른다.
    func update(_ alarm: AlarmSetting) async {
        alarm.needsSync = true
        save()
        await push(alarm)
        await rescheduleLocal()
    }

    func delete(_ alarm: AlarmSetting) async {
        let serverID = alarm.serverAlarmID
        context.delete(alarm)
        save()
        if let serverID {
            try? await client.deleteAlarm(id: serverID)
        }
        await rescheduleLocal()
    }

    func toggle(_ alarm: AlarmSetting, on: Bool) async {
        alarm.isEnabled = on
        await update(alarm)
    }

    // MARK: - 서버와 맞추기

    /// 한 건을 서버에 밀어 넣는다. 실패하면 `needsSync` 를 남겨 둔다.
    private func push(_ alarm: AlarmSetting) async {
        let key = alarm.localID
        guard !Self.inFlight.contains(key) else { return }
        Self.inFlight.insert(key)
        defer { Self.inFlight.remove(key) }

        let payload = AlarmPayload(alarm)
        do {
            if let id = alarm.serverAlarmID {
                _ = try await client.updateAlarm(id: id, payload: payload)
            } else {
                let created = try await client.createAlarm(payload)
                alarm.serverAlarmID = created.alarmID
            }
            alarm.needsSync = false
            save()
        } catch {
            log.info("알람을 서버에 못 넘겼다. 로컬 백업만 울린다: \(String(describing: error), privacy: .private)")
        }
    }

    /// 앱을 열 때 한 번. 밀린 것을 밀어 넣고, 서버에만 있는 알람을 내려받는다.
    func syncAll() async {
        for alarm in all() where alarm.needsSync {
            await push(alarm)
        }

        // 아직 올라가는 중인 알람이 있으면 내려받지 않는다. 서버 목록에는 있는데
        // 기기 쪽에는 서버 ID 가 아직 안 적혀 있어 같은 알람을 새로 만들어 버린다.
        guard Self.inFlight.isEmpty, let remote = try? await client.alarms() else {
            await rescheduleLocal()
            return
        }

        let known = Set(all().compactMap(\.serverAlarmID))
        for dto in remote where !known.contains(dto.alarmID) {
            // 기기를 바꿨거나 앱을 다시 깔았다. 서버에 남아 있던 알람을 되살린다.
            let alarm = AlarmSetting(
                hour: dto.hour,
                minute: dto.minute,
                weekdays: Set(dto.weekdays),
                timezoneID: dto.timezone,
                sourceKind: AlarmSourceKind(rawValue: dto.source.kind) ?? .auto,
                sourceID: dto.source.id,
                sourceTitle: dto.source.title,
                situation: dto.source.situation.flatMap(Situation.init(rawValue:)),
                label: dto.label ?? String(localized: "알람"),
                isEnabled: dto.enabled
            )
            alarm.serverAlarmID = dto.alarmID
            alarm.needsSync = false
            context.insert(alarm)
        }
        save()
        await rescheduleLocal()
    }

    func rescheduleLocal() async {
        await LocalAlarmScheduler.reschedule(all())
    }

    private func save() {
        do {
            try context.save()
        } catch {
            log.error("알람을 저장하지 못했다: \(String(describing: error), privacy: .private)")
        }
    }
}
