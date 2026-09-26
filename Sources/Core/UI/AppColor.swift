import SwiftUI

/// 앱 강조색 중 에셋의 AccentColor 로 덮이지 않는 것만 여기 모은다.
///
/// 색을 화면마다 흩어 놓으면 한 곳만 바꾸고 나머지를 놓친다. 실제로 즐겨찾기 하트가
/// 목록에서는 분홍, 재생 화면에서는 무색이었다. 그래서 값을 여기 한 자리에 둔다.
enum AppColor {
    /// 즐겨찾기 하트. 담긴 것과 담을 수 있는 것을 이 색으로 구분한다.
    static let favorite = Color.red
    /// 즐겨찾기에서 뺄 때. 빨강과 나란히 놓여도 갈리게 회색을 쓴다.
    static let favoriteOff = Color.gray
}
