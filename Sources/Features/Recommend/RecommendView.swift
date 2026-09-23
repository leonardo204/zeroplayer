import SwiftUI

struct RecommendView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "추천",
                systemImage: "sparkles",
                description: Text("M4 에서 상황별 큐레이션을 붙인다.")
            )
            .navigationTitle("추천")
        }
    }
}

#Preview {
    RecommendView()
}
