import Foundation

/// PostHog, behind a facade so call sites stay one line and provider-agnostic.
///
/// This is a cross-cutting service rather than a feature module: it is called
/// from everywhere, so it stays compiled in and simply becomes a no-op when
/// `FEATURE_ANALYTICS` is removed or the API key is still a placeholder.
///
/// Opt-out is a user-facing setting (Settings → Privacy) and is honoured before
/// anything reaches the network.
enum Analytics {

    private static let optOutKey = "analytics.optOut"

    static var isEnabled: Bool {
        FeatureFlags.analytics && AppConfig.postHogAPIKey != nil && !hasOptedOut
    }

    static var hasOptedOut: Bool {
        get { UserDefaults.standard.bool(forKey: optOutKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: optOutKey)
            #if canImport(PostHog) && FEATURE_ANALYTICS
            if newValue {
                PostHogSDK.shared.optOut()
            } else {
                PostHogSDK.shared.optIn()
            }
            #endif
            Log.analytics.notice("Analytics opt-out set to \(newValue).")
        }
    }

    // MARK: - Lifecycle

    static func start() {
        guard FeatureFlags.analytics else { return }
        guard let apiKey = AppConfig.postHogAPIKey else {
            Log.analytics.warning(
                "PostHog is not configured — set POSTHOG_API_KEY in Config/Secrets.xcconfig to enable analytics."
            )
            return
        }

        #if canImport(PostHog) && FEATURE_ANALYTICS
        let config = PostHogConfig(projectToken: apiKey, host: AppConfig.postHogHost)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        config.sessionReplay = false
        PostHogSDK.shared.setup(config)

        if hasOptedOut {
            PostHogSDK.shared.optOut()
        }
        #else
        Log.analytics.debug("PostHog is not linked — analytics calls are no-ops.")
        #endif
    }

    // MARK: - Events

    static func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        #if canImport(PostHog) && FEATURE_ANALYTICS
        PostHogSDK.shared.capture(event.name, properties: event.properties)
        #endif
        Log.analytics.debug("track \(event.name, privacy: .public)")
    }

    /// Ties events to a signed-in user. Called from `RootView` when auth state
    /// flips; safe to call repeatedly with the same id.
    static func identify(userID: String, email: String?) {
        guard isEnabled else { return }
        #if canImport(PostHog) && FEATURE_ANALYTICS
        var properties: [String: Any] = [:]
        if let email { properties["email"] = email }
        PostHogSDK.shared.identify(userID, userProperties: properties)
        #endif
    }

    /// Clears the identity on sign-out so the next user isn't merged into the
    /// previous one's profile.
    static func reset() {
        #if canImport(PostHog) && FEATURE_ANALYTICS
        guard FeatureFlags.analytics else { return }
        PostHogSDK.shared.reset()
        #endif
    }
}
