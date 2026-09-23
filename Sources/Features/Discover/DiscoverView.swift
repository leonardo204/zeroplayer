import SwiftUI

struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "탐색",
                systemImage: "magnifyingglass",
                description: Text("M2 에서 방송국 목록과 검색을 붙인다.")
            )
            .navigationTitle("탐색")
        }
    }
}

#Preview {
    DiscoverView()
}
