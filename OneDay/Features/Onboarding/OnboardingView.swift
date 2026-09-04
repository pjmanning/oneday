import SwiftUI

/// Multi-page, skippable onboarding.
///
/// Completion is recorded by `RootRouter` (in `UserDefaults`), not here, so the
/// screen has no opinion about what comes next.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var selection = OnboardingPage.all.first?.id ?? 0

    private var pages: [OnboardingPage] { OnboardingPage.all }
    private var isLastPage: Bool { selection == pages.last?.id }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $selection) {
                    ForEach(pages) { page in
                        Tab(value: page.id) {
                            OnboardingPageView(page: page)
                        }
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                controls
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        Analytics.track(.onboardingSkipped(page: selection))
                        onFinish()
                    }
                    .accessibilityIdentifier("onboarding.skip")
                }
            }
        }
        .task {
            Analytics.track(.onboardingStarted)
        }
        .accessibilityIdentifier("onboarding")
    }

    private var controls: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PrimaryButton(
                title: isLastPage ? "Get started" : "Continue",
                systemImage: isLastPage ? nil : "arrow.right"
            ) {
                advance()
            }
            .accessibilityIdentifier("onboarding.continue")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
        .readableContentColumn()
    }

    private func advance() {
        guard !isLastPage else {
            onFinish()
            return
        }
        guard let index = pages.firstIndex(where: { $0.id == selection }),
              pages.indices.contains(index + 1)
        else {
            onFinish()
            return
        }
        withAnimation {
            selection = pages[index + 1].id
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: Theme.Spacing.xl)

            OnboardingArtwork(page: page)

            VStack(spacing: Theme.Spacing.sm) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer(minLength: Theme.Spacing.xxl)
        }
        .readableContentColumn()
        .accessibilityIdentifier("onboarding.page.\(page.id)")
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
