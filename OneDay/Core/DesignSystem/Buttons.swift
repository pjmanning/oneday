import SwiftUI

/// The kit's two button primitives.
///
/// Both are thin wrappers over the system styles rather than hand-drawn
/// controls, so they inherit iOS 26 behaviour — including Liquid Glass — without
/// us reimplementing it. Reach for `PrimaryButton` for the one action a screen
/// is about, `SecondaryButton` for everything else.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Layout.controlHeight)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: Theme.Radius.md))
        .controlSize(.large)
        .disabled(isLoading)
    }
}

struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Layout.controlHeight)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: Theme.Radius.md))
        .controlSize(.large)
    }
}

#Preview("Buttons") {
    VStack(spacing: Theme.Spacing.md) {
        PrimaryButton(title: "Continue", systemImage: "arrow.right") {}
        PrimaryButton(title: "Working", isLoading: true) {}
        SecondaryButton(title: "Maybe later") {}
    }
    .padding()
}
