import SwiftUI

/// The single place that decides what the window shows.
///
/// Screens never navigate to each other across features — they report back to
/// `RootRouter` and it picks the next surface. That is what lets any one
/// feature be deleted without the others noticing.
struct RootView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(RootRouter.self) private var router
    @Environment(AuthService.self) private var auth
    @Environment(PurchaseService.self) private var purchases
    #if FEATURE_PUSH
    @Environment(PushService.self) private var push
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router

        destinationView
            .animation(.smooth(duration: 0.35), value: router.destination)
            .sheet(isPresented: $router.isPresentingPaywall) {
                upgradePaywall
            }
            .task {
                router.update(authState: auth.state, isPremium: purchases.isPremium)
            }
            .onChange(of: auth.state) { _, newState in
                router.update(authState: newState, isPremium: purchases.isPremium)
                Task { await app.propagateIdentity() }
            }
            .onChange(of: purchases.isPremium) { _, isPremium in
                router.update(authState: auth.state, isPremium: isPremium)
            }
            .onChange(of: scenePhase) { _, phase in
                // State the user can change outside the app: notification
                // permission in iOS Settings, a subscription in the App Store.
                // Without this the UI keeps showing what was true at launch.
                guard phase == .active else { return }
                Task { await refreshExternallyOwnedState() }
            }
    }

    /// Re-reads anything the user can change while the app is backgrounded.
    private func refreshExternallyOwnedState() async {
        #if FEATURE_PUSH
        await push.refreshPermission()
        #endif
        // RevenueCat's customerInfoStream already pushes entitlement changes,
        // so there is nothing to poll for purchases here.
    }

    @ViewBuilder
    private var destinationView: some View {
        switch router.destination {
        case .launch:
            LaunchView()

        case .onboarding:
            #if FEATURE_ONBOARDING
            OnboardingView {
                router.completeOnboarding()
                // Ask for push *after* onboarding: iOS gives you one prompt, so
                // spend it when the user knows what they're saying yes to.
                #if FEATURE_PUSH
                Task { await push.requestPermissionIfNeeded() }
                #endif
            }
            #else
            LaunchView()
            #endif

        case .auth:
            #if FEATURE_AUTH
            AuthView()
            #else
            LaunchView()
            #endif

        case .paywall:
            #if FEATURE_PAYWALL
            PaywallView(source: "first-run") {
                router.markPaywallSeen()
            }
            #else
            LaunchView()
            #endif

        case .main:
            MainTabView()
        }
    }

    @ViewBuilder
    private var upgradePaywall: some View {
        #if FEATURE_PAYWALL
        PaywallView(source: "upgrade") {
            router.isPresentingPaywall = false
        }
        #else
        EmptyView()
        #endif
    }
}
