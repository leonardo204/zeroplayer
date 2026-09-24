import SwiftUI

/// 1.7 에서 올라온 사용자에게 한 번만 보여 주는 안내.
///
/// 유튜브 재생목록을 쓰던 사람이 업데이트하면 그 기능이 통째로 사라져 있다.
/// 설명 없이 없애면 앱이 고장 난 것으로 보인다. 왜 뺐는지와 대신 무엇이 생겼는지를 적는다.
/// 근거 조항은 `docs/05-ads-policy.md` 1번이다.
struct YouTubeRemovedView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                        .accessibilityHidden(true)

                    Text("유튜브 재생목록은 더 쓸 수 없습니다")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    Text("""
                        유튜브는 화면을 끈 채 소리만 재생하는 것을 약관에서 막고 있습니다. \
                        이 앱은 취침·운전처럼 화면을 보지 않는 상황에 쓰는 앱이라, \
                        약관을 지키면서 그 기능을 유지할 방법이 없었습니다.
                        """)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("대신 이런 것이 생겼습니다")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 14) {
                        point("sparkles", String(localized: "상황에 맞는 추천"),
                              String(localized: "취침·운전·공부·작업·기상 중 하나를 고르면 지금 시각에 맞는 방송을 골라 줍니다."))
                        point("magnifyingglass", String(localized: "전 세계 인터넷 라디오와 팟캐스트"),
                              String(localized: "방송국 수천 곳과 팟캐스트를 찾아 들을 수 있습니다."))
                        point("timer", String(localized: "자동 종료 타이머"),
                              String(localized: "정한 시간이 되면 소리가 서서히 줄며 꺼집니다."))
                        point("alarm", String(localized: "알람"),
                              String(localized: "정한 시각에 알림이 오고, 누르면 그 방송이 바로 재생됩니다."))
                    }

                    Text("전에 쓰시던 알람과 채널 목록은 그대로 옮겨 뒀습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .navigationTitle("달라진 점")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("확인") { dismiss() }
                }
            }
        }
    }

    private func point(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    YouTubeRemovedView()
}
