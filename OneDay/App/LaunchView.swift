import SwiftUI

/// Shown while Clerk restores a cached session.
///
/// It deliberately matches the `UILaunchScreen` in `Config/Info.plist` — same
/// background colour, same mark — so the hand-off from the system launch screen
/// to SwiftUI is invisible. If you change one, change the other.
struct LaunchView: View {
    var body: some View {
        ZStack {
            // Generated asset symbol, not a string — a renamed colorset becomes
            // a compile error instead of a silently transparent background.
            Color.launchBackground
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "swift")
                    .font(.system(size: 72, weight: .medium))
                    .foregroundStyle(Theme.accent.gradient)

                ProgressView()
                    .controlSize(.regular)
            }
        }
        .accessibilityIdentifier("launch")
    }
}

#Preview {
    LaunchView()
}
