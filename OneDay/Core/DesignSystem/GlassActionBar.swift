import SwiftUI

/// A floating action bar that sits above content with real Liquid Glass.
///
/// This is the kit's **one** piece of custom glass, and it follows the rules
/// from Apple's *Adopting Liquid Glass*:
///
/// * Glass belongs to the navigation / floating-control layer, never to content.
///   Cards, list rows and form sections in this app stay opaque.
/// * Related glass shapes go inside a `GlassEffectContainer` so they blend and
///   morph as one element instead of sampling each other.
/// * `.interactive()` on the primary control, so it responds to touch the way
///   system chrome does.
/// * Never stack glass on glass — the content behind this bar is solid.
///
/// Used by the paywall CTA and the Home "new item" action.
struct GlassActionBar<Content: View>: View {
    var spacing: CGFloat = Theme.Spacing.sm
    @ViewBuilder var content: Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) {
                content
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }
}

/// A circular floating button on glass — the Home screen's compose action.
struct GlassCircleButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A wide floating call to action on glass — the soft paywall's primary button.
struct GlassCapsuleButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Layout.controlHeight)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .disabled(isLoading)
    }
}

#Preview("Glass action bar") {
    ZStack(alignment: .bottom) {
        // Deliberately opaque: glass must never sample glass.
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(0..<20, id: \.self) { index in
                    Text("Content row \(index)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.Radius.md))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))

        GlassActionBar {
            GlassCapsuleButton(title: "Upgrade", systemImage: "sparkles") {}
            GlassCircleButton(systemImage: "plus", accessibilityLabel: "Add") {}
        }
    }
}
