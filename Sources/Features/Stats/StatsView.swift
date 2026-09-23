import SwiftUI

struct StatsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "기록",
                systemImage: "chart.bar",
                description: Text("M3 에서 청취 기록과 월간 리포트를 붙인다.")
            )
            .navigationTitle("기록")
        }
    }
}

#Preview {
    StatsView()
}
