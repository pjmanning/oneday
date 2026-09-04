import SwiftUI

/// TikTok-style vertical feed — one post fills the viewport at a time.
///
/// No external links. One headline. Duration badge. AI summary placeholder.
/// Composer opens from the glass action when today's post lock allows it.
struct HomeView: View {
    @Environment(BackendService.self) private var backend
    @Environment(DailyPostLock.self) private var dailyLock
    @Environment(FollowingCapsStore.self) private var caps

    @State private var model = FeedViewModel()
    @State private var isShowingComposer = false
    @State private var lockAlertPresented = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content
                .safeAreaInset(edge: .bottom) { floatingActions }
        }
        .task { await model.observeFeed(using: backend) }
        .sheet(isPresented: $isShowingComposer) {
            ComposerView()
        }
        .alert("One post per day", isPresented: $lockAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dailyLock.lockMessage)
        }
        .accessibilityIdentifier("feed")
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let posts) where posts.isEmpty:
            ContentUnavailableView {
                Label("No OneDays yet", systemImage: "sun.max")
            } description: {
                Text("Follow a few people — or post today's clip — and the feed will fill in.")
            }
            .foregroundStyle(.white)

        case .loaded(let posts):
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { post in
                        FeedPostPage(post: post)
                            .containerRelativeFrame(.vertical)
                            .id(post.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load feed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
            .foregroundStyle(.white)
            .accessibilityIdentifier("feed.error")
        }
    }

    private var floatingActions: some View {
        GlassActionBar {
            Text(caps.statusSummary)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("feed.capsStatus")

            Spacer()

            GlassCircleButton(
                systemImage: dailyLock.hasPostedToday ? "checkmark" : "plus",
                accessibilityLabel: dailyLock.hasPostedToday ? "Already posted today" : "Compose today's OneDay"
            ) {
                if dailyLock.hasPostedToday {
                    lockAlertPresented = true
                } else {
                    isShowingComposer = true
                }
            }
            .accessibilityIdentifier("feed.compose")
        }
    }
}

private struct FeedPostPage: View {
    let post: FeedPost

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Full-bleed visual plane — placeholder until real video lands.
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.18, blue: 0.22),
                    Color(red: 0.05, green: 0.07, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.22))
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Spacer()

                HStack(spacing: Theme.Spacing.xs) {
                    Text(post.authorDisplayName)
                        .font(.subheadline.weight(.semibold))
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(post.durationLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("feed.meta")

                Text(post.headline)
                    .font(.title2.weight(.bold))
                    .lineLimit(3)
                    .accessibilityIdentifier("feed.headline")

                AISummaryPlaceholder(summary: post.aiSummary, headline: post.headline)
            }
            .foregroundStyle(.white)
            .padding(Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed.post.\(post.id)")
    }
}
