import Foundation

/// 알람을 어느 길로 보낼지 한 곳에서 정한다.
///
/// 두 길이 함께 돌면 같은 시각에 두 번 울린다. 그래서 하나만 고른다.
///
/// - iOS 26 이상에서 AlarmKit 권한을 받았으면 AlarmKit 하나만 쓴다.
///   시스템 알람이라 무음 모드를 뚫고, 서버 푸시도 로컬 백업 알림도 필요 없다.
/// - 그 밖에는 지금까지의 길 — 서버 푸시 + 로컬 백업 알림 — 을 쓴다.
enum AlarmDelivery {
    /// 이 기기가 AlarmKit 을 쓸 수 있는지. 권한과는 별개다.
    static var isAlarmKitAvailable: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// 지금 실제로 AlarmKit 으로 가는지.
    static var usesAlarmKit: Bool {
        if #available(iOS 26.0, *) { return AlarmKitScheduler.isAuthorized }
        return false
    }

    /// 아직 AlarmKit 권한을 묻지 않았는지. 알람을 켤 때 이 값을 보고 묻는다.
    static var needsAlarmKitPermission: Bool {
        if #available(iOS 26.0, *) { return AlarmKitScheduler.isUndecided }
        return false
    }

    /// 알람을 켤 때 권한을 묻는다. AlarmKit 을 못 쓰는 기기에서는 아무 일도 하지 않는다.
    @discardableResult
    static func requestAlarmKitPermission() async -> Bool {
        if #available(iOS 26.0, *) { return await AlarmKitScheduler.requestAuthorization() }
        return false
    }
}
