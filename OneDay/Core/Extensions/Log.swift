import OSLog

/// App-wide loggers. Use these instead of `print` so output survives release
/// builds and shows up in Console.app filtered by subsystem.
///
/// ```swift
/// Log.paywall.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
/// ```
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.swiftuitemplate.demo"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let backend = Logger(subsystem: subsystem, category: "backend")
    static let paywall = Logger(subsystem: subsystem, category: "paywall")
    static let billing = Logger(subsystem: subsystem, category: "billing")
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
    static let push = Logger(subsystem: subsystem, category: "push")
    static let feedback = Logger(subsystem: subsystem, category: "feedback")
}
