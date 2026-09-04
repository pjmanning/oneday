import SwiftUI

struct LaunchView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .tint(.primary)
        }
        .accessibilityIdentifier("launch.root")
    }
}

#Preview {
    LaunchView()
}
