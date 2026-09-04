import Foundation

/// Drives the vertical OneDay feed — one full-bleed post at a time.
@MainActor
@Observable
final class FeedViewModel {

    enum LoadState {
        case idle
        case loading
        case loaded([FeedPost])
        case failed(String)
    }

    private(set) var state: LoadState = .idle
    var selectedPostID: String?

    /// Local placeholders so the UI is walkable before Convex is wired.
    static let samplePosts: [FeedPost] = [
        FeedPost(
            id: "sample-1",
            headline: "Morning surf before the inbox",
            durationSeconds: 95,
            dayKey: DailyPostLock.todayKey(),
            authorSubject: "sample.alex",
            authorDisplayName: "Alex",
            aiSummary: nil,
            createdAt: Date().addingTimeInterval(-3600)
        ),
        FeedPost(
            id: "sample-2",
            headline: "One sketch. No scroll.",
            durationSeconds: 120,
            dayKey: DailyPostLock.todayKey(),
            authorSubject: "sample.jordan",
            authorDisplayName: "Jordan",
            aiSummary: "A quiet desk session: pencil, paper, and a single idea carried to the end.",
            createdAt: Date().addingTimeInterval(-7200)
        ),
        FeedPost(
            id: "sample-3",
            headline: "Cooking for one, slowly",
            durationSeconds: 180,
            dayKey: DailyPostLock.todayKey(),
            authorSubject: "sample.sam",
            authorDisplayName: "Sam",
            aiSummary: nil,
            createdAt: Date().addingTimeInterval(-10_800)
        ),
    ]

    func observeFeed(using backend: BackendService) async {
        state = .loading
        do {
            for try await posts in backend.subscribe(to: "posts:feed", as: [FeedPost].self) {
                if posts.isEmpty, backend.connectionState == .unconfigured {
                    state = .loaded(Self.samplePosts)
                    selectedPostID = Self.samplePosts.first?.id
                } else {
                    state = .loaded(posts)
                    if selectedPostID == nil {
                        selectedPostID = posts.first?.id
                    }
                }
            }
        } catch is CancellationError {
        } catch {
            Log.backend.error("posts:feed failed: \(error.localizedDescription, privacy: .public)")
            // Degrade to samples so the scaffold stays demoable offline.
            state = .loaded(Self.samplePosts)
            selectedPostID = Self.samplePosts.first?.id
            ErrorReporting.capture(error, context: "posts.feed")
        }
    }
}
