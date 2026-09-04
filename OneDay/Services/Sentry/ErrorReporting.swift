import Foundation

#if canImport(Sentry) && FEATURE_ERROR_REPORTING
import Sentry
#endif

/// Sentry, behind the same style of facade as `Analytics`.
///
/// Catch blocks call `ErrorReporting.capture(error, context:)` instead of
/// importing Sentry, so swapping crash reporters is a change to this one file.
enum ErrorReporting {

    static var isEnabled: Bool {
        FeatureFlags.errorReporting && AppConfig.sentryDSN != nil
    }

    // MARK: - Lifecycle

    static func start() {
        guard FeatureFlags.errorReporting else { return }
        guard let dsn = AppConfig.sentryDSN else {
            Log.app.warning("Sentry is not configured — set SENTRY_DSN in Config/Secrets.xcconfig.")
            return
        }

        #if canImport(Sentry) && FEATURE_ERROR_REPORTING
        SentrySDK.start { options in
            options.dsn = dsn
            options.releaseName = "\(AppConfig.bundleIdentifier)@\(AppConfig.version)+\(AppConfig.build)"
            options.enableAutoSessionTracking = true
            options.attachViewHierarchy = false

            #if DEBUG
            options.environment = "debug"
            options.debug = false
            // Everything, so you can see your test event land immediately.
            options.tracesSampleRate = 1.0
            #else
            options.environment = "production"
            // Keep production tracing cheap; raise it once you know your volume.
            options.tracesSampleRate = 0.2
            #endif
        }
        #else
        Log.app.debug("Sentry is not linked — error reporting calls are no-ops.")
        #endif
    }

    // MARK: - Reporting

    /// Records a caught error. `context` shows up as a tag so you can tell
    /// "purchase failed" from "billing lookup failed" at a glance.
    static func capture(_ error: Error, context: String) {
        Log.app.error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
        guard isEnabled else { return }
        #if canImport(Sentry) && FEATURE_ERROR_REPORTING
        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: context, key: "context")
        }
        #endif
    }

    /// A breadcrumb trail makes a crash report readable. Cheap — call freely.
    static func breadcrumb(_ message: String, category: String = "app") {
        guard isEnabled else { return }
        #if canImport(Sentry) && FEATURE_ERROR_REPORTING
        let crumb = Breadcrumb(level: .info, category: category)
        crumb.message = message
        SentrySDK.addBreadcrumb(crumb)
        #endif
    }

    static func setUser(id: String?, email: String?) {
        guard isEnabled else { return }
        #if canImport(Sentry) && FEATURE_ERROR_REPORTING
        guard let id else {
            SentrySDK.setUser(nil)
            return
        }
        let user = User(userId: id)
        user.email = email
        SentrySDK.setUser(user)
        #endif
    }

    #if DEBUG
    /// Backs the DEBUG-only "Send test event" row in Settings, so you can prove
    /// the DSN works before you ship.
    static func sendTestEvent() {
        struct SentryTestError: LocalizedError {
            var errorDescription: String? { "Test event from \(AppConfig.displayName) \(AppConfig.versionDisplay)" }
        }
        breadcrumb("User tapped Send test event", category: "diagnostics")
        capture(SentryTestError(), context: "diagnostics.test-event")
    }
    #endif
}
