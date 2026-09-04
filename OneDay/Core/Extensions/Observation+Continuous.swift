import Foundation
import Observation

/// Runs `body` now, and again every time any `@Observable` property it touched
/// changes.
///
/// `withObservationTracking` fires `onChange` exactly once, which makes it
/// awkward for mirroring a third-party `@Observable` (Clerk) into our own
/// services. This re-arms the tracking after each change.
///
/// Keep the returned token for as long as you want the loop to run; drop it or
/// call `cancel()` to stop.
///
/// ```swift
/// observation = observeContinuously { [weak self] in
///     self?.apply(Clerk.shared.user)
/// }
/// ```
@MainActor
@discardableResult
func observeContinuously(_ body: @escaping @MainActor () -> Void) -> ObservationToken {
    let token = ObservationToken()
    track(body, token: token)
    return token
}

@MainActor
private func track(_ body: @escaping @MainActor () -> Void, token: ObservationToken) {
    guard !token.isCancelled else { return }
    withObservationTracking {
        body()
    } onChange: { [weak token] in
        // Weak throughout: releasing the token is what ends the loop.
        Task { @MainActor in
            guard let token else { return }
            track(body, token: token)
        }
    }
}

/// Keeps an `observeContinuously` loop alive. Release it or call `cancel()` to stop.
///
/// `Sendable` because `withObservationTracking`'s change handler is `@Sendable`
/// and needs to hold this weakly; the flag is behind a lock so that is honest
/// rather than merely asserted.
final class ObservationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock()
        return cancelled
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock()
        cancelled = true
    }
}
