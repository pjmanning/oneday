import Foundation

/// Limits how much of other people's time you take — and how much of yours
/// they take. Both modes are stubbed for day-one scaffolding.
///
/// - `people`: follow at most 30 people.
/// - `minutes`: watch at most 30 minutes of feed per calendar day.
enum FollowingCapMode: String, CaseIterable, Identifiable, Sendable {
    case people
    case minutes

    var id: String { rawValue }

    static let maxPeople = 30
    static let maxMinutesPerDay = 30

    var title: String {
        switch self {
        case .people: "30 people"
        case .minutes: "30 minutes / day"
        }
    }

    var detail: String {
        switch self {
        case .people:
            "Follow up to \(Self.maxPeople) people. Quiet by design."
        case .minutes:
            "Spend at most \(Self.maxMinutesPerDay) minutes in the feed each day."
        }
    }
}

/// Local stub for following / watch-time caps. Replace with Convex-backed
/// preferences once accounts sync across devices.
@MainActor
@Observable
final class FollowingCapsStore {
    private enum Key {
        static let mode = "oneday.followingCapMode"
        static let followingCount = "oneday.followingCountStub"
        static let minutesWatchedToday = "oneday.minutesWatchedTodayStub"
        static let watchDayKey = "oneday.watchDayKey"
    }

    private let defaults: UserDefaults

    var mode: FollowingCapMode {
        didSet { defaults.set(mode.rawValue, forKey: Key.mode) }
    }

    /// Stub count of people the user follows.
    private(set) var followingCount: Int {
        didSet { defaults.set(followingCount, forKey: Key.followingCount) }
    }

    /// Stub minutes watched today (resets when the calendar day changes).
    private(set) var minutesWatchedToday: Int {
        didSet { defaults.set(minutesWatchedToday, forKey: Key.minutesWatchedToday) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Key.mode) ?? FollowingCapMode.people.rawValue
        self.mode = FollowingCapMode(rawValue: raw) ?? .people
        self.followingCount = defaults.object(forKey: Key.followingCount) as? Int ?? 0
        self.minutesWatchedToday = defaults.object(forKey: Key.minutesWatchedToday) as? Int ?? 0
        rollWatchBudgetIfNeeded()
    }

    var peopleRemaining: Int {
        max(0, FollowingCapMode.maxPeople - followingCount)
    }

    var minutesRemaining: Int {
        max(0, FollowingCapMode.maxMinutesPerDay - minutesWatchedToday)
    }

    var statusSummary: String {
        switch mode {
        case .people:
            "Following \(followingCount)/\(FollowingCapMode.maxPeople)"
        case .minutes:
            "\(minutesWatchedToday)/\(FollowingCapMode.maxMinutesPerDay) min today"
        }
    }

    /// Stub: attempt to follow one more person. Returns false when capped.
    @discardableResult
    func tryFollow() -> Bool {
        guard mode == .people else { return true }
        guard followingCount < FollowingCapMode.maxPeople else { return false }
        followingCount += 1
        return true
    }

    /// Stub: record one minute of watch time. Returns false when the daily
    /// minute budget is exhausted.
    @discardableResult
    func recordWatchMinute() -> Bool {
        rollWatchBudgetIfNeeded()
        guard mode == .minutes else { return true }
        guard minutesWatchedToday < FollowingCapMode.maxMinutesPerDay else { return false }
        minutesWatchedToday += 1
        return true
    }

    func resetStubs() {
        followingCount = 0
        minutesWatchedToday = 0
        defaults.set(Self.todayKey(), forKey: Key.watchDayKey)
    }

    private func rollWatchBudgetIfNeeded() {
        let today = Self.todayKey()
        let stored = defaults.string(forKey: Key.watchDayKey)
        if stored != today {
            minutesWatchedToday = 0
            defaults.set(today, forKey: Key.watchDayKey)
        }
    }

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
