import Foundation

#if canImport(ClerkKit) && FEATURE_AUTH
import ClerkKit
#endif

/// Owns the Clerk session and republishes it as plain `AuthState` / `AuthUser`.
///
/// Two things make this safe on a fresh clone:
/// * With no publishable key, `isConfigured` is `false` and nothing calls into
///   ClerkKit — the sign-in screen explains what to fill in instead of crashing.
/// * With `FEATURE_AUTH` removed the type still exists and reports `.signedOut`,
///   so the router simply skips the auth step.
@MainActor
@Observable
final class AuthService {

    private(set) var state: AuthState = .loading
    private(set) var user: AuthUser?

    /// Surfaced under the sign-in buttons. Cleared on the next attempt.
    private(set) var lastErrorMessage: String?

    /// `false` when `CLERK_PUBLISHABLE_KEY` is still `REPLACE_ME`.
    let isConfigured: Bool = AppConfig.clerkPublishableKey != nil && FeatureFlags.auth

    private var observation: ObservationToken?

    // MARK: - Lifecycle

    /// Configures Clerk and starts mirroring its state. Called once from
    /// `SwiftUITemplateApp`.
    func start() {
        guard FeatureFlags.auth else {
            state = .signedOut
            return
        }

        guard let publishableKey = AppConfig.clerkPublishableKey else {
            Log.auth.warning(
                "Clerk is not configured — set CLERK_PUBLISHABLE_KEY in Config/Secrets.xcconfig. See docs/SETUP.md."
            )
            state = .signedOut
            return
        }

        #if canImport(ClerkKit) && FEATURE_AUTH
        Clerk.configure(publishableKey: publishableKey)

        // `Clerk` is @Observable, so mirror it instead of polling.
        observation = observeContinuously { [weak self] in
            guard let self else { return }
            let clerk = Clerk.shared
            self.apply(isLoaded: clerk.isLoaded, session: clerk.session, user: clerk.user)
        }
        #else
        Log.auth.warning("ClerkKit is not linked — auth is disabled. Add the clerk-ios package to re-enable it.")
        state = .signedOut
        #endif
    }

    // MARK: - Sign in

    func signInWithApple() async {
        await attempt("Sign in with Apple", analyticsMethod: "apple") {
            #if canImport(ClerkKit) && FEATURE_AUTH
            try await Clerk.shared.auth.signInWithApple()
            #endif
        }
    }

    func signInWithGoogle() async {
        await attempt("Sign in with Google", analyticsMethod: "google") {
            #if canImport(ClerkKit) && FEATURE_AUTH
            try await Clerk.shared.auth.signInWithOAuth(provider: .google)
            #endif
        }
    }

    /// Escape hatch for an unconfigured clone: lets you walk the whole shell
    /// before wiring Clerk. It is only reachable while `isConfigured` is
    /// `false`, so it cannot survive into a real build.
    func signInAsPreviewUser() {
        guard !isConfigured else { return }
        user = .preview
        state = .signedIn
        Log.auth.notice("Signed in as the preview user because Clerk is not configured.")
    }

    // MARK: - Sign out / delete

    func signOut() async {
        guard isConfigured else { return endPreviewSession() }
        await attempt("Sign out") {
            #if canImport(ClerkKit) && FEATURE_AUTH
            try await Clerk.shared.auth.signOut()
            #endif
        }
    }

    /// Deletes the Clerk user. App Store review requires an in-app path for
    /// this whenever you offer account creation.
    func deleteAccount() async {
        guard isConfigured else { return endPreviewSession() }
        await attempt("Delete account") {
            #if canImport(ClerkKit) && FEATURE_AUTH
            guard let user = Clerk.shared.user else { return }
            _ = try await user.delete()
            #endif
        }
    }

    private func endPreviewSession() {
        user = nil
        state = .signedOut
        lastErrorMessage = nil
    }

    // MARK: - Internals

    /// - Parameter analyticsMethod: set for sign-in paths only, so `signOut` and
    ///   `deleteAccount` don't report themselves as successful sign-ins.
    private func attempt(
        _ label: String,
        analyticsMethod: String? = nil,
        _ work: () async throws -> Void
    ) async {
        lastErrorMessage = nil
        guard isConfigured else {
            lastErrorMessage = "Clerk is not configured. Set CLERK_PUBLISHABLE_KEY in Config/Secrets.xcconfig."
            return
        }
        do {
            try await work()
            if let analyticsMethod {
                Analytics.track(.authSucceeded(method: analyticsMethod))
            }
        } catch is CancellationError {
            // The user dismissed the system sheet — not an error worth showing.
        } catch {
            Log.auth.error("\(label) failed: \(error.localizedDescription, privacy: .public)")
            ErrorReporting.capture(error, context: label)
            lastErrorMessage = error.localizedDescription
        }
    }

    #if canImport(ClerkKit) && FEATURE_AUTH
    private func apply(isLoaded: Bool, session: Session?, user clerkUser: User?) {
        guard isLoaded else {
            state = .loading
            return
        }

        if let clerkUser, session?.status == .active {
            user = AuthUser(
                id: clerkUser.id,
                firstName: clerkUser.firstName,
                lastName: clerkUser.lastName,
                email: clerkUser.primaryEmailAddress?.emailAddress,
                imageURL: clerkUser.hasImage ? URL(string: clerkUser.imageUrl) : nil
            )
            state = .signedIn
        } else {
            user = nil
            state = .signedOut
        }
    }
    #endif
}
