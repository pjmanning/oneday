import SwiftUI

/// The empty state shown whenever an integration is still on placeholder keys.
///
/// A template that crashes on a missing key wastes the buyer's first ten
/// minutes. Every service in `Services/` degrades into one of these instead,
/// naming the exact setting to fill in and where.
struct SetupRequiredView: View {
    let integration: String
    let message: String
    var settingName: String?

    var body: some View {
        ContentUnavailableView {
            Label("\(integration) needs setup", systemImage: "wrench.and.screwdriver")
        } description: {
            VStack(spacing: Theme.Spacing.xs) {
                Text(message)
                if let settingName {
                    Text(settingName)
                        .font(.footnote.monospaced())
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Color(.secondarySystemFill), in: .rect(cornerRadius: Theme.Radius.sm))
                }
                Text("See docs/SETUP.md")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("setupRequired.\(integration.lowercased())")
    }
}

/// Inline variant for use inside a `Form` / `List` section.
struct SetupRequiredRow: View {
    let integration: String
    let settingName: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("\(integration) not configured")
                    .font(.subheadline.weight(.medium))
                Text("Set \(settingName) in Config/Secrets.xcconfig")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
        .accessibilityIdentifier("setupRequiredRow.\(integration.lowercased())")
    }
}

#Preview("Setup required") {
    SetupRequiredView(
        integration: "RevenueCat",
        message: "Add your RevenueCat API key to load offerings and enable purchases.",
        settingName: "REVENUECAT_API_KEY"
    )
}
