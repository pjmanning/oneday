import Foundation

/// Typed access to build configuration.
///
/// The chain is: `Config/Base.xcconfig` (placeholders) → `Config/Secrets.xcconfig`
/// (your real values, gitignored) → the `STConfig` dictionary in
/// `Config/Info.plist` → this type.
///
/// **This is the only place in the app that reads `Bundle.main`.** Services ask
/// `AppConfig` for what they need and disable themselves when it is missing, so
/// a fresh clone with untouched placeholders still launches.
enum AppConfig {

    // MARK: - Integrations

    static var clerkPublishableKey: String? { string(.clerkPublishableKey) }
    static var convexDeploymentURL: String? { string(.convexDeploymentURL) }
    static var revenueCatAPIKey: String? { string(.revenueCatAPIKey) }
    static var postHogAPIKey: String? { string(.postHogAPIKey) }
    static var postHogHost: String { string(.postHogHost) ?? "https://us.i.posthog.com" }
    static var sentryDSN: String? { string(.sentryDSN) }
    static var oneSignalAppID: String? { string(.oneSignalAppID) }
    static var featureBasePortalURL: URL? { url(.featureBasePortalURL) }
    static var featureBaseChangelogURL: URL? { url(.featureBaseChangelogURL) }

    // MARK: - Legal / support

    static var privacyPolicyURL: URL? { url(.privacyPolicyURL) }
    static var termsURL: URL? { url(.termsURL) }
    static var supportEmail: String? { string(.supportEmail) }

    // MARK: - Bundle metadata

    static var displayName: String {
        bundleString("CFBundleDisplayName") ?? bundleString("CFBundleName") ?? "App"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "unknown.bundle.id"
    }

    static var version: String { bundleString("CFBundleShortVersionString") ?? "0.0.0" }
    static var build: String { bundleString("CFBundleVersion") ?? "0" }
    static var versionDisplay: String { "\(version) (\(build))" }

    // MARK: - Diagnostics

    /// Every key that is still a placeholder, for the Settings diagnostics row
    /// and the startup log. Empty means the app is fully wired.
    static var unconfiguredKeys: [String] {
        Key.allCases.filter { string($0) == nil }.map(\.rawValue)
    }

    /// Logs a single, actionable summary at launch instead of crashing on a
    /// force-unwrapped key somewhere deep in a service.
    static func logConfigurationStatus() {
        let missing = unconfiguredKeys
        guard !missing.isEmpty else {
            Log.app.info("AppConfig: all keys configured.")
            return
        }
        Log.app.warning(
            """
            AppConfig: \(missing.count) key(s) still set to REPLACE_ME — the matching \
            features are disabled: \(missing.joined(separator: ", ")). \
            Fix: cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig and fill it in. \
            See docs/SETUP.md.
            """
        )
    }

    // MARK: - Plumbing

    enum Key: String, CaseIterable {
        case clerkPublishableKey = "ClerkPublishableKey"
        case convexDeploymentURL = "ConvexDeploymentURL"
        case revenueCatAPIKey = "RevenueCatAPIKey"
        case postHogAPIKey = "PostHogAPIKey"
        case postHogHost = "PostHogHost"
        case sentryDSN = "SentryDSN"
        case oneSignalAppID = "OneSignalAppID"
        case featureBasePortalURL = "FeatureBasePortalURL"
        case featureBaseChangelogURL = "FeatureBaseChangelogURL"
        case privacyPolicyURL = "PrivacyPolicyURL"
        case termsURL = "TermsURL"
        case supportEmail = "SupportEmail"
    }

    /// Read once at first use and flattened to `[String: String]`, which is
    /// `Sendable` — so this needs no actor, lock or `nonisolated(unsafe)`.
    /// `Info.plist` is immutable at runtime, so one snapshot is enough.
    private static let configDictionary: [String: String] = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "STConfig") as? [String: Any] ?? [:]
        return raw.compactMapValues { $0 as? String }
    }()

    /// Returns `nil` — never an empty or placeholder string — so callers can use
    /// `guard let` and get a disabled feature rather than a broken one.
    private static func string(_ key: Key) -> String? {
        guard let raw = configDictionary[key.rawValue] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("REPLACE_ME") else { return nil }
        return trimmed
    }

    private static func url(_ key: Key) -> URL? {
        guard let value = string(key), let url = URL(string: value), url.scheme != nil else {
            return nil
        }
        return url
    }

    private static func bundleString(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
