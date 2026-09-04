import SwiftUI

/// Placeholder for the eventual clip AI summary.
///
/// Shows server-provided text when present; otherwise a clear "coming soon"
/// affordance so product intent is visible without inventing content.
struct AISummaryPlaceholder: View {
    let summary: String?
    let headline: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label("AI summary", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            } else {
                Text("A short summary of “\(headline)” will appear here once generation is wired.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(Color.black.opacity(0.35), in: .rect(cornerRadius: Theme.Radius.sm))
        .accessibilityIdentifier("feed.aiSummary")
    }
}
