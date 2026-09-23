import SwiftUI

struct PresetsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "프리셋",
                systemImage: "square.grid.2x2",
                description: Text("M3 에서 상황 프리셋과 타이머를 붙인다.")
            )
            .navigationTitle("프리셋")
        }
    }
}

#Preview {
    PresetsView()
}
