import Foundation
import SwiftUI

/// Decides which of the five top-level surfaces the app shows.
///
/// ```
/// Launch → Onboarding? → Auth? → (soft paywall)? → Main tabs
/// ```
///
/// Every step disappears when its feature is switched off, and the router copes
/// with any combination — that is the whole reason it exists rather than having
/// the screens push each other.
@MainActor
@Observable
final class RootRouter {

    enum Destination: Hashable {
        /// Waiting on Clerk to restore a session. Shows the launch view so
        /// returning users never see a flash of the sign-in screen.
        case launch
        case onboarding
        case auth
        case paywall
        case main
    }

    private(set) var destination: Destination = .launch
    var selectedTab: AppTab = .initial

    /// Set while the paywall is presented *over* the main shell (the "upgrade"
    /// path), as opposed to being the destination (the first-run path).
    var isPresentingPaywall = false

    // MARK: - Inputs

    private(set) var authState: AuthState = .loading
    private(set) var isPremium = false

    /// `false` until the first `update`, so the initial call always resolves a
    /// destination even when nothing has changed yet. Without this the app
    /// would sit on the launch screen whenever the first reported state happens
    /// to match the defaults.
    private var hasResolvedOnce = false

    /// Called by `RootView` on appear and whenever auth or entitlement state
    /// changes.
    func update(authState: AuthState, isPremium: Bool) {
        let isUnchanged = hasResolvedOnce
            && authState == self.authState
            && isPremium == self.isPremium

        self.authState = authState
        self.isPremium = isPremium

        guard !isUnchanged else { return }
        hasResolvedOnce = true
        recompute()
    }

    // MARK: - Persisted progress

    private enum Key {
        static let hasCompletedOnboarding = "app.hasCompletedOnboarding"
        static let hasSeenPaywall = "app.hasSeenPaywall"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Key.hasCompletedOnboarding)
    }

    var hasSeenPaywall: Bool {
        defaults.bool(forKey: Key.hasSeenPaywall)
    }

    // MARK: - Transitions

    func completeOnboarding() {
        defaults.set(true, forKey: Key.hasCompletedOnboarding)
        Analytics.track(.onboardingCompleted)
        recompute()
    }

    /// The paywall is soft: seeing it once is enough to move on.
    func markPaywallSeen() {
        defaults.set(true, forKey: Key.hasSeenPaywall)
        recompute()
    }

    /// Resets first-run state. Wired to a DEBUG-only Settings row so you can
    /// re-walk onboarding without deleting the app.
    func resetFirstRunState() {
        defaults.removeObject(forKey: Key.hasCompletedOnboarding)
        defaults.removeObject(forKey: Key.hasSeenPaywall)
        recompute()
    }

    // MARK: - Resolution

    private func recompute() {
        let next = resolvedDestination()
        guard next != destination else { return }
        Log.app.debug("Router: \(String(describing: self.destination)) → \(String(describing: next))")
        destination = next
    }

    private func resolvedDestination() -> Destination {
        if FeatureFlags.onboarding, !hasCompletedOnboarding {
            return .onboarding
        }

        if FeatureFlags.auth {
            switch authState {
            case .loading: return .launch
            case .signedOut: return .auth
            case .signedIn: break
            }
        }

        if FeatureFlags.paywall, !hasSeenPaywall, !isPremium {
            return .paywall
        }

        return .main
    }
}
