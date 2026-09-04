import Foundation

/// Enforces OneDay's core rule: one post per user per calendar day.
///
/// Day-one scaffolding uses a local day key. Wire `markPostedToday` to the
/// Convex `posts:create` success path and prefer the server's `hasPostedToday`
/// query when online.
@MainActor
@Observable
final class DailyPostLock {
    private enum Key {
        static let lastPostDay = "oneday.lastPostDay"
    }

    private let defaults: UserDefaults
    private(set) var lastPostDayKey: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lastPostDayKey = defaults.string(forKey: Key.lastPostDay)
    }

    var hasPostedToday: Bool {
        lastPostDayKey == Self.todayKey()
    }

    var lockMessage: String {
        "You've already shared today's OneDay. Come back tomorrow."
    }

    func markPostedToday() {
        let key = Self.todayKey()
        lastPostDayKey = key
        defaults.set(key, forKey: Key.lastPostDay)
    }

    /// DEBUG / Settings helper so you can re-test the composer lock.
    func clear() {
        lastPostDayKey = nil
        defaults.removeObject(forKey: Key.lastPostDay)
    }

    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
