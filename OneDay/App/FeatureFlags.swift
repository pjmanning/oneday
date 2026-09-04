import Foundation

/// The one place to see what is switched on.
///
/// The *real* switch is the `FEATURE_FLAGS` list in `Config/Base.xcconfig`,
/// which feeds `SWIFT_ACTIVE_COMPILATION_CONDITIONS`. Removing a token there
/// removes every reference to that feature at compile time, so you can then
/// delete the whole `Features/<Name>/` folder and the app still builds. That is
/// what makes modules genuinely deletable rather than merely hidden.
///
/// The booleans below mirror those conditions for runtime branching and for
/// showing state in Settings → Diagnostics.
///
/// ## Turning a feature off
/// 1. Delete its token from `FEATURE_FLAGS` in `Config/Base.xcconfig`.
/// 2. Delete `SwiftUITemplate/Features/<Name>/` (optional — it just stops compiling in).
/// 3. Build. Nothing else should need editing.
enum FeatureFlags {

    // MARK: - Feature modules

    #if FEATURE_ONBOARDING
    static let onboarding = true
    #else
    static let onboarding = false
    #endif

    #if FEATURE_AUTH
    static let auth = true
    #else
    static let auth = false
    #endif

    #if FEATURE_PAYWALL
    static let paywall = true
    #else
    static let paywall = false
    #endif

    #if FEATURE_HOME
    static let home = true
    #else
    static let home = false
    #endif

    #if FEATURE_PROFILE
    static let profile = true
    #else
    static let profile = false
    #endif

    #if FEATURE_SETTINGS
    static let settings = true
    #else
    static let settings = false
    #endif

    #if FEATURE_BILLING
    static let billing = true
    #else
    static let billing = false
    #endif

    // MARK: - Services

    #if FEATURE_ANALYTICS
    static let analytics = true
    #else
    static let analytics = false
    #endif

    #if FEATURE_ERROR_REPORTING
    static let errorReporting = true
    #else
    static let errorReporting = false
    #endif

    #if FEATURE_PUSH
    static let push = true
    #else
    static let push = false
    #endif

    #if FEATURE_FEATUREBASE
    static let featureBase = true
    #else
    static let featureBase = false
    #endif

    #if FEATURE_LOTTIE
    static let lottie = true
    #else
    static let lottie = false
    #endif

    // MARK: - Behaviour

    /// The paywall is soft by design: it is shown once after sign-in and can be
    /// dismissed. Flip to `true` if your product genuinely cannot function
    /// without a subscription.
    static let paywallBlocksApp = false

    /// Diagnostics listing, surfaced in Settings under `#if DEBUG`.
    static var all: [(name: String, isOn: Bool)] {
        [
            ("Onboarding", onboarding),
            ("Auth", auth),
            ("Paywall", paywall),
            ("Feed", home),
            ("Profile", profile),
            ("Settings", settings),
            ("Billing", billing),
            ("Analytics", analytics),
            ("Error reporting", errorReporting),
            ("Push", push),
            ("FeatureBase", featureBase),
            ("Lottie", lottie),
        ]
    }
}
