import Foundation

/// Composer rules for a OneDay: one headline, 60–180 seconds, no links.
@MainActor
@Observable
final class ComposerViewModel {
    static let minDurationSeconds = 60
    static let maxDurationSeconds = 180
    static let maxHeadlineLength = 80

    var headline = ""
    var durationSeconds = 90
    private(set) var isPublishing = false
    var errorMessage: String?
    var didPublish = false

    var canPublish: Bool {
        let trimmed = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && trimmed.count <= Self.maxHeadlineLength
            && !containsURL(trimmed)
            && durationSeconds >= Self.minDurationSeconds
            && durationSeconds <= Self.maxDurationSeconds
            && !isPublishing
    }

    var validationHint: String? {
        let trimmed = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Add one headline." }
        if trimmed.count > Self.maxHeadlineLength {
            return "Headline max \(Self.maxHeadlineLength) characters."
        }
        if containsURL(trimmed) {
            return "No external links — keep it in the clip."
        }
        if durationSeconds < Self.minDurationSeconds || durationSeconds > Self.maxDurationSeconds {
            return "Clips are 1–3 minutes."
        }
        return nil
    }

    func publish(using backend: BackendService, lock: DailyPostLock) async {
        guard canPublish else {
            errorMessage = validationHint
            return
        }
        if lock.hasPostedToday {
            errorMessage = lock.lockMessage
            return
        }

        isPublishing = true
        defer { isPublishing = false }

        let trimmed = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let dayKey = DailyPostLock.todayKey()

        do {
            if backend.connectionState != .unconfigured {
                try await backend.mutation(
                    "posts:create",
                    args: [
                        "headline": .string(trimmed),
                        "durationSeconds": .int(durationSeconds),
                        "dayKey": .string(dayKey),
                    ]
                )
            }
            // Local lock stub always updates so the UI respects 1/day offline.
            lock.markPostedToday()
            didPublish = true
            Analytics.track(.oneDayPublished(durationSeconds: durationSeconds))
        } catch {
            ErrorReporting.capture(error, context: "posts.create")
            errorMessage = error.localizedDescription
        }
    }

    private func containsURL(_ text: String) -> Bool {
        let detectors: [String] = ["http://", "https://", "www."]
        let lower = text.lowercased()
        if detectors.contains(where: { lower.contains($0) }) {
            return true
        }
        // Crude domain heuristic — stubs the product rule without a full parser.
        return text.range(of: #"\b[a-z0-9-]+\.(com|net|org|io|app)\b"#, options: .regularExpression) != nil
    }
}
