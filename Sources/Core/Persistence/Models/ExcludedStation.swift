import Foundation
import SwiftData

/// 자동 선택에서 빼 달라고 한 방송국.
///
/// '삭제' 가 아니다. 목록은 서버가 내려 주고 여섯 시간마다 갱신되므로 기기가 지울 수
/// 있는 것이 아니다. 여기 담긴 것은 **앱이 알아서 고를 때 빼 달라**는 뜻이고,
/// 탐색 탭에서 직접 찾아 누르는 것은 그대로 된다(`docs/12-exclusions.md`).
///
/// 서버에도 같은 목록을 둔다. iOS 25 이하에서는 알람에 무엇을 틀지 **서버가** 고르기
/// 때문에, 기기에만 두면 아침에 그 방송이 그대로 온다. 올리는 것은 방송국 번호뿐이고
/// 무엇을 얼마나 들었는지는 여전히 기기 밖으로 나가지 않는다.
@Model
final class ExcludedStation {
    @Attribute(.unique) var itemID: String
    /// 설정 화면에 보여 줄 이름. 목록에서 사라진 방송도 무엇이었는지 알 수 있어야 한다.
    var title: String
    var addedAt: Date
    /// 서버에 아직 못 올렸는지. 앱을 다시 열 때 밀어 넣는다.
    var needsSync: Bool

    init(itemID: String, title: String, addedAt: Date = .now, needsSync: Bool = true) {
        self.itemID = itemID
        self.title = title
        self.addedAt = addedAt
        self.needsSync = needsSync
    }
}
