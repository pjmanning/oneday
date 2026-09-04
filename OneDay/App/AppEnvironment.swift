import SwiftUI

/// Owns the long-lived services and starts them in the right order.
///
/// Order matters in exactly one place: `AuthService.start()` configures Clerk,
/// and `BackendService.start()` builds a `ConvexClientWithAuth` whose
/// `ClerkConvexAuthProvider` binds to that Clerk instance. Configure Clerk
/// second and Convex never sees a session.
///
/// Services are injected individually into the SwiftUI environment so a view
/// declares exactly what it uses:
///
/// ```swift
/// @Environment(AuthService.self) private var auth
/// ```
@MainActor
@Observable
final class AppEnvironment {
    let router = RootRouter()
    let auth = AuthService()
    let backend = BackendService()
    let purchases = PurchaseService()
    let dailyPostLock = DailyPostLock()
    let followingCaps = FollowingCapsStore()
    #if FEATURE_PUSH
    let push = PushService()
    #endif

    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        AppConfig.logConfigurationStatus()

        // Crash reporting first, so failures in everything below get captured.
        ErrorReporting.start()
        Analytics.start()

        auth.start()
        backend.start()
        purchases.start()
        #if FEATURE_PUSH
        push.start()
        #endif

        Analytics.track(.appLaunched)
    }

    /// Fans a change in identity out to every service that keys off the user.
    /// Called from `RootView` whenever `AuthService.state` changes.
    func propagateIdentity() async {
        guard let user = auth.user else {
            Analytics.reset()
            ErrorReporting.setUser(id: nil, email: nil)
            #if FEATURE_PUSH
            push.setExternalUserID(nil)
            #endif
            await purchases.logOutUser()
            return
        }

        Analytics.identify(userID: user.id, email: user.email)
        ErrorReporting.setUser(id: user.id, email: user.email)
        #if FEATURE_PUSH
        push.setExternalUserID(user.id)
        #endif
        await purchases.setUserID(user.id)
    }
}

extension View {
    /// Injects every service in one call, so `RootView` and previews stay short.
    func withAppEnvironment(_ environment: AppEnvironment) -> some View {
        let base = self
            .environment(environment)
            .environment(environment.router)
            .environment(environment.auth)
            .environment(environment.backend)
            .environment(environment.purchases)
            .environment(environment.dailyPostLock)
            .environment(environment.followingCaps)

        #if FEATURE_PUSH
        return base.environment(environment.push)
        #else
        return base
        #endif
    }
}
