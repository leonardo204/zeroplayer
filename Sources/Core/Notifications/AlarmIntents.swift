import AlarmKit
import AppIntents
import Foundation

/// 알람 화면의 단추에 물리는 동작.
///
/// `LiveActivityIntent` 라서 시스템이 앱 화면을 열지 않고 프로세스만 깨워 실행한다.
/// **`AudioPlaybackIntent` 를 함께 채택해야 오디오 세션이 열린다.** 이것이 빠지면
/// `setActive(true)` 가 `'!int'`(CannotInterruptOthers) 로 거부되고, 우회해도
/// 재생이 붙지 않는다. 실기기에서 재서 확인한 것이고 애플 문서에는 없다
/// (`docs/10-alarmkit.md` 10.2). 지우지 말 것.
@available(iOS 26.0, *)
struct WakeRadioIntent: LiveActivityIntent, AudioPlaybackIntent {
    static var title: LocalizedStringResource = "방송 켜기"
    static var description = IntentDescription("알람이 울릴 때 고른 방송을 재생합니다.")
    /// 단축어 목록에 내놓지 않는다. 알람 단추 전용이다.
    static var isDiscoverable: Bool = false

    /// 시스템이 준 AlarmKit 알람 ID.
    @Parameter(title: "알람 ID") var alarmID: String
    /// 기기 안 알람(`AlarmSetting.localID`). 남은 연쇄 알람을 치울 때 쓴다.
    @Parameter(title: "묶음 ID") var rootID: String
    /// 예약할 때 골라 둔 것. 비어 있으면 상황을 보고 그때 고른다.
    @Parameter(title: "소스 ID") var sourceID: String
    @Parameter(title: "소스 종류") var sourceKind: String
    @Parameter(title: "제목") var sourceTitle: String
    @Parameter(title: "상황") var situation: String

    init() {}

    init(alarmID: UUID, rootID: UUID, item: PlayableItem?, situation: Situation?) {
        self.alarmID = alarmID.uuidString
        self.rootID = rootID.uuidString
        self.sourceID = item?.id ?? ""
        self.sourceKind = item?.kind.rawValue ?? ""
        self.sourceTitle = item?.title ?? ""
        self.situation = situation?.rawValue ?? ""
    }

    func perform() async throws -> some IntentResult {
        AlarmKitScheduler.finish(alarmID: alarmID, rootID: rootID)
        await AlarmPlaybackBridge.shared.startFromAlarm(
            item: playable, situation: Situation(rawValue: situation))
        return .result()
    }

    private var playable: PlayableItem? {
        guard !sourceID.isEmpty, let kind = SourceKind(rawValue: sourceKind) else { return nil }
        return PlayableItem(
            id: sourceID,
            kind: kind,
            title: sourceTitle.isEmpty ? String(localized: "알람") : sourceTitle,
            subtitle: String(localized: "알람")
        )
    }
}

/// 알람 화면의 정지 단추. 알람을 끄는 것은 시스템이 하고, 우리는 뒤에 걸어 둔
/// 연쇄 알람을 치운다. 이것이 없으면 2분 뒤 알람이 또 울린다.
@available(iOS 26.0, *)
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "끄기"
    static var description = IntentDescription("알람을 끄고 뒤에 걸린 알람까지 치웁니다.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "알람 ID") var alarmID: String
    @Parameter(title: "묶음 ID") var rootID: String

    init() {}

    init(alarmID: UUID, rootID: UUID) {
        self.alarmID = alarmID.uuidString
        self.rootID = rootID.uuidString
    }

    func perform() async throws -> some IntentResult {
        AlarmKitScheduler.finish(alarmID: alarmID, rootID: rootID)
        return .result()
    }
}
