import SwiftUI

/// The main shell.
///
/// A plain `TabView` with `Tab` items, which is what makes the tab bar render
/// as system Liquid Glass on iOS 26 — floating, translucent, and morphing on
/// scroll — with no custom material code. Each tab's root is its own
/// `NavigationStack` so toolbars get the same treatment.
///
/// The tabs themselves come from `AppTab`, whose cases appear and disappear
/// with the `FEATURE_*` flags.
struct MainTabView: View {
    @Environment(RootRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    view(for: tab)
                }
            }
        }
        .accessibilityIdentifier("mainTabs")
    }

    @ViewBuilder
    private func view(for tab: AppTab) -> some View {
        switch tab {
        #if FEATURE_HOME
        case .home: HomeView()
        #endif
        #if FEATURE_PROFILE
        case .profile: ProfileView()
        #endif
        #if FEATURE_SETTINGS
        case .settings: SettingsView()
        #endif
        }
    }
}
