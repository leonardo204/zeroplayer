import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "설정",
                systemImage: "gearshape",
                description: Text("M6 에서 알람, M7 에서 히든 해제를 붙인다.")
            )
            .navigationTitle("설정")
        }
    }
}

#Preview {
    SettingsView()
}
