import ActivityKit
import AlarmKit
import Foundation
import SwiftUI
import os

/// 위젯 표시에 쓰라고 시스템에 함께 넘기는 값. 지금은 이름만 담는다.
@available(iOS 26.0, *)
struct ZPAlarmMetadata: AlarmMetadata {
    var label: String

    init(label: String) {
        self.label = label
    }
}

/// iOS 26 이상에서 알람을 거는 곳.
///
/// 시스템 알람이라 무음 모드와 집중 모드를 뚫고, 알람 화면의 '방송 켜기' 를 누르면
/// 앱 화면이 열리지 않은 채 방송이 시작된다. 측정 근거는 `docs/10-alarmkit.md` 다.
///
/// 알람음은 시스템 기본음을 쓴다. 방송 앞부분을 받아 알람음으로 쓰는 것도 되지만
/// (파일은 발화 시점에 읽힌다) 커스텀 알람음은 **한 번 울리고 끝나고** 기본음보다
/// 작게 들린다. 깨우는 일에는 기본음이 낫다. 방송은 단추를 누른 뒤부터 나온다.
///
/// 커스텀 알람음이 한 번만 울리는 것은 우리가 못 고친다. 그래서 알람 하나를 걸 때
/// `chainInterval` 분 간격으로 `chainCount` 개를 함께 걸고, 사용자가 끄거나 방송을
/// 켜면 남은 것을 치운다. 예약 개수는 제약이 아니다(1000건까지 확인).
@available(iOS 26.0, *)
enum AlarmKitScheduler {
    /// 한 알람이 실제로 거는 개수. 첫 발화 + 2분 간격 세 번.
    static let chainCount = 4
    /// 연쇄 간격(분).
    static let chainInterval = 2

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "alarm")

    // MARK: - 권한

    static var isAuthorized: Bool {
        AlarmManager.shared.authorizationState == .authorized
    }

    static var isUndecided: Bool {
        AlarmManager.shared.authorizationState == .notDetermined
    }

    /// 사용자가 알람을 켤 때 부른다. 권한 창의 앞 문단은 시스템이 쓰고,
    /// `NSAlarmKitUsageDescription` 에 적은 한 줄이 그 아래 붙는다.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            log.info("AlarmKit 권한 \(String(describing: state), privacy: .public)")
            return state == .authorized
        } catch {
            log.error("AlarmKit 권한을 묻지 못했다: \(String(describing: error), privacy: .private)")
            return false
        }
    }

    // MARK: - 예약

    /// 알람 목록 전체를 다시 건다. 만들고 고치고 지운 뒤에 한 번 부른다.
    ///
    /// `resolve` 는 자동 선택 알람이 무엇을 틀지 미리 고르는 통로다. 지금 고른 것을
    /// 인텐트 인자에 넣어 두면 알람 시각에 서버에 못 닿아도 틀 것이 있다.
    static func reschedule(
        _ alarms: [AlarmSetting],
        resolve: (AlarmSetting) async -> PlayableItem?
    ) async {
        guard isAuthorized else {
            log.info("AlarmKit 권한이 없어 알람을 걸지 않는다")
            return
        }
        cancelAll()

        // 고른 알람음을 미리 그려 둔다. 파일은 울릴 때 읽히므로 여기서 써 두면 된다.
        var liveSounds: Set<String> = []
        for alarm in alarms where alarm.isEnabled {
            if let name = alarm.ensureSoundFile() { liveSounds.insert(name) }
        }
        AlarmSoundStore.prune(keeping: liveSounds)

        var scheduled = 0
        for alarm in alarms where alarm.isEnabled {
            // `??` 는 오른쪽을 autoclosure 로 받아서 await 를 못 쓴다.
            var item = alarm.playable
            if item == nil { item = await resolve(alarm) }
            scheduled += await schedule(alarm, item: item)
        }
        log.info("AlarmKit 알람 \(scheduled)건을 걸었다")
    }

    /// 알람 하나를 연쇄로 건다. 실제로 걸린 개수를 돌려준다.
    private static func schedule(_ alarm: AlarmSetting, item: PlayableItem?) async -> Int {
        let root = alarm.localID
        var count = 0
        // 우리 알람음을 고르지 않았으면 기본음이다. 기본음은 1분 넘게 반복해서 울린다.
        let sound: AlertConfiguration.AlertSound = alarm.ensureSoundFile()
            .map { .named($0) } ?? .default

        for index in 0..<chainCount {
            guard let schedule = schedule(for: alarm, offsetMinutes: index * chainInterval) else {
                // 자정을 넘으면 요일까지 밀려야 한다. 거기까지는 하지 않고 건너뛴다.
                log.info("연쇄 \(index) 번이 자정을 넘어 건너뛴다")
                continue
            }
            let id = chainID(root: root, index: index)
            let config = AlarmManager.AlarmConfiguration(
                schedule: schedule,
                attributes: attributes(for: alarm),
                stopIntent: StopAlarmIntent(alarmID: id, rootID: root),
                secondaryIntent: WakeRadioIntent(
                    alarmID: id, rootID: root, item: item, situation: alarm.situation),
                sound: sound)
            do {
                _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
                count += 1
            } catch {
                log.error("알람을 걸지 못했다: \(String(describing: error), privacy: .private)")
            }
        }
        return count
    }

    private static func attributes(for alarm: AlarmSetting) -> AlarmAttributes<ZPAlarmMetadata> {
        let title = alarm.label.isEmpty ? String(localized: "알람") : alarm.label
        // `stopButton` 을 생략하는 초기화는 iOS 26.1 부터다. 26.0 도 받으려면 직접 넘긴다.
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: AlarmButton(
                text: LocalizedStringResource(stringLiteral: String(localized: "끄기")),
                textColor: .white,
                systemImageName: "stop.fill"),
            secondaryButton: AlarmButton(
                text: LocalizedStringResource(stringLiteral: String(localized: "방송 켜기")),
                textColor: .white,
                systemImageName: "dot.radiowaves.left.and.right"),
            // `.custom` 이라야 우리 인텐트가 돈다. `.countdown` 은 시스템 스누즈다.
            secondaryButtonBehavior: .custom)
        return AlarmAttributes<ZPAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: ZPAlarmMetadata(label: title),
            tintColor: .orange)
    }

    /// 요일 반복이면 주간 일정, 한 번만이면 다음 그 시각 하나.
    private static func schedule(
        for alarm: AlarmSetting, offsetMinutes: Int
    ) -> Alarm.Schedule? {
        let total = alarm.hour * 60 + alarm.minute + offsetMinutes
        guard total < 24 * 60 else { return nil }
        let hour = total / 60
        let minute = total % 60

        let days = alarm.weekdays
        guard !days.isEmpty else {
            guard let date = nextOccurrence(hour: hour, minute: minute) else { return nil }
            return .fixed(date)
        }
        let weekdays = days.sorted().compactMap(Self.weekday(from:))
        guard !weekdays.isEmpty else { return nil }
        return .relative(.init(
            time: .init(hour: hour, minute: minute),
            repeats: .weekly(weekdays)))
    }

    /// 오늘 그 시각이 지났으면 내일.
    private static func nextOccurrence(hour: Int, minute: Int) -> Date? {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.nextDate(
            after: .now, matching: components, matchingPolicy: .nextTime)
    }

    /// 1=일 … 7=토. `AlarmSetting.weekdays` 와 `Locale.Weekday` 를 맞춘다.
    private static func weekday(from raw: Int) -> Locale.Weekday? {
        switch raw {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }

    // MARK: - 치우기

    /// 걸어 둔 것을 전부 치운다. 이 앱의 AlarmKit 알람은 모두 우리가 건 것이다.
    static func cancelAll() {
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        for alarm in alarms {
            if alarm.state == .alerting { try? AlarmManager.shared.stop(id: alarm.id) }
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
        if !alarms.isEmpty { log.info("AlarmKit 알람 \(alarms.count)건을 치웠다") }
    }

    /// 사용자가 끄거나 방송을 켰다. 이번 묶음의 남은 알람을 치운다.
    ///
    /// 알람 자체를 끄는 것은 시스템이 한다. `stop(id:)` 은 인텐트 안에서 부르면
    /// `com.apple.AlarmKit.Alarm Code=0` 으로 실패하는데, 실패해도 동작에는 지장이
    /// 없어서 오류를 삼킨다(`docs/10-alarmkit.md` 10.5).
    static func finish(alarmID: String, rootID: String) {
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        guard let root = UUID(uuidString: rootID) else { return }
        let alive = Set(((try? AlarmManager.shared.alarms) ?? []).map(\.id))
        for index in 0..<chainCount {
            let id = chainID(root: root, index: index)
            guard alive.contains(id) else { continue }
            try? AlarmManager.shared.cancel(id: id)
        }
        log.info("알람 묶음 \(rootID.prefix(8), privacy: .public) 의 남은 알람을 치웠다")
    }

    /// 한 알람이 거는 여러 개에 줄 식별자. 마지막 바이트만 바꿔 되짚을 수 있게 한다.
    ///
    /// 되짚기가 필요한 이유는 `AlarmManager.shared.alarms` 가 우리가 넘긴
    /// 메타데이터를 돌려주지 않기 때문이다. 어느 묶음인지 ID 로만 알 수 있다.
    static func chainID(root: UUID, index: Int) -> UUID {
        var raw = root.uuid
        raw.15 ^= UInt8(index & 0xFF)
        return UUID(uuid: raw)
    }
}
