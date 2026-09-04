import Foundation

#if canImport(ConvexMobile)
import Combine
// ConvexMobile predates Swift 6 strict concurrency: `ConvexClient` is a
// non-Sendable class whose calls are `nonisolated async`. `@preconcurrency`
// downgrades the resulting sending-value diagnostics to warnings. The client is
// only ever touched from the main actor here, which is what makes that safe.
// The ClerkConvex bridge imports it the same way.
@preconcurrency import ConvexMobile
#endif
#if canImport(ClerkConvex) && FEATURE_AUTH
import ClerkConvex
#endif

/// The app's single Convex connection.
///
/// It is a `ConvexClientWithAuth` driven by `ClerkConvexAuthProvider`, which is
/// the wiring Clerk and Convex officially support: sign in through Clerk and
/// the Convex client picks up the JWT on its own — there is no `login()` call
/// anywhere in this app.
///
/// Everything crossing into `Features/` is plain Swift (`BackendValue`,
/// `Decodable` models, `AsyncThrowingStream`), so ConvexMobile stops here.
@MainActor
@Observable
final class BackendService {

    enum ConnectionState: Hashable, Sendable {
        case unconfigured
        case connecting
        /// Connected, and Convex has accepted a Clerk token.
        case authenticated
        /// Connected, but running as an anonymous client. Queries that call
        /// `ctx.auth.getUserIdentity()` will refuse to serve data.
        case unauthenticated
    }

    private(set) var connectionState: ConnectionState = .unconfigured

    let isConfigured: Bool = AppConfig.convexDeploymentURL != nil

    #if canImport(ConvexMobile)
    private var client: ConvexClientWithAuth<String>?
    private var authStateCancellable: AnyCancellable?
    #endif

    // MARK: - Lifecycle

    /// Builds the client. Must run *after* `AuthService.start()` so Clerk is
    /// configured before `ClerkConvexAuthProvider` binds to it.
    func start() {
        guard let deploymentURL = AppConfig.convexDeploymentURL else {
            Log.backend.warning(
                "Convex is not configured — run `npx convex dev` and set CONVEX_DEPLOYMENT_URL in Config/Secrets.xcconfig."
            )
            connectionState = .unconfigured
            return
        }

        #if canImport(ConvexMobile) && canImport(ClerkConvex) && FEATURE_AUTH
        let client = ConvexClientWithAuth(
            deploymentUrl: deploymentURL,
            authProvider: ClerkConvexAuthProvider()
        )
        self.client = client
        connectionState = .connecting
        observeAuthState(of: client)

        #elseif canImport(ConvexMobile)
        // Auth is switched off: talk to Convex anonymously. Only functions that
        // don't call ctx.auth.getUserIdentity() will return data.
        let provider = AnonymousAuthProvider()
        let client = ConvexClientWithAuth<String>(deploymentUrl: deploymentURL, authProvider: provider)
        self.client = client
        connectionState = .unauthenticated

        #else
        Log.backend.warning("ConvexMobile is not linked — backend calls will fail. Add the convex-swift package in Xcode.")
        connectionState = .unconfigured
        #endif
    }

    #if canImport(ConvexMobile)
    private func observeAuthState(of client: ConvexClientWithAuth<String>) {
        // ConvexMobile publishes auth state through Combine; this is the one
        // place in the app that bridges it back to @Observable.
        authStateCancellable = client.authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .authenticated: self.connectionState = .authenticated
                case .unauthenticated: self.connectionState = .unauthenticated
                case .loading: self.connectionState = .connecting
                }
            }
    }
    #endif

    // MARK: - Queries

    /// Subscribes to a Convex query and yields a new value every time the
    /// underlying data changes.
    ///
    /// - Parameters:
    ///   - name: `"module:functionName"`, e.g. `"demoItems:list"`.
    ///   - args: Named arguments matching the function's validator.
    ///   - type: The `Decodable` you expect back.
    ///
    /// The upstream subscription is cancelled when the returned stream is
    /// dropped, so `for try await` inside a `.task` modifier cleans up on
    /// disappear without any extra bookkeeping.
    func subscribe<T: Decodable & Sendable>(
        to name: String,
        args: BackendArgs = [:],
        as type: T.Type = T.self
    ) -> AsyncThrowingStream<T, Error> {
        #if canImport(ConvexMobile)
        guard let client else {
            return .failing(with: isConfigured ? BackendError.clientUnavailable : BackendError.notConfigured)
        }

        return AsyncThrowingStream { continuation in
            // `onTermination` is @Sendable but AnyCancellable is not, so the
            // subscription is handed over through a locked box.
            let box = CancellableBox()
            continuation.onTermination = { _ in box.cancel() }

            box.store(
                client
                    .subscribe(to: name, with: Self.encode(args), yielding: T.self)
                    .sink { completion in
                        switch completion {
                        case .finished:
                            continuation.finish()
                        case .failure(let error):
                            continuation.finish(throwing: BackendError.transport(error.localizedDescription))
                        }
                    } receiveValue: { value in
                        continuation.yield(value)
                    }
            )
        }
        #else
        return .failing(with: BackendError.clientUnavailable)
        #endif
    }

    // MARK: - Mutations and actions

    @discardableResult
    func mutation<T: Decodable & Sendable>(
        _ name: String,
        args: BackendArgs = [:],
        as type: T.Type
    ) async throws -> T {
        #if canImport(ConvexMobile)
        guard let client else { throw unavailableError }
        do {
            return try await client.mutation(name, with: Self.encode(args))
        } catch {
            throw BackendError.transport(error.localizedDescription)
        }
        #else
        throw BackendError.clientUnavailable
        #endif
    }

    func mutation(_ name: String, args: BackendArgs = [:]) async throws {
        #if canImport(ConvexMobile)
        guard let client else { throw unavailableError }
        do {
            try await client.mutation(name, with: Self.encode(args))
        } catch {
            throw BackendError.transport(error.localizedDescription)
        }
        #else
        throw BackendError.clientUnavailable
        #endif
    }

    /// Runs a Convex **action** — the only function type allowed to reach
    /// third-party APIs. Stripe lookups go through here.
    func action<T: Decodable & Sendable>(
        _ name: String,
        args: BackendArgs = [:],
        as type: T.Type
    ) async throws -> T {
        #if canImport(ConvexMobile)
        guard let client else { throw unavailableError }
        do {
            return try await client.action(name, with: Self.encode(args))
        } catch {
            throw BackendError.transport(error.localizedDescription)
        }
        #else
        throw BackendError.clientUnavailable
        #endif
    }

    // MARK: - Internals

    private var unavailableError: BackendError {
        isConfigured ? .clientUnavailable : .notConfigured
    }

    #if canImport(ConvexMobile)
    /// `nonisolated` matters: inside a `@MainActor` type this would otherwise be
    /// main-actor isolated, and its non-Sendable result could not be passed to
    /// ConvexMobile's `nonisolated async` calls. Being nonisolated makes each
    /// returned dictionary a fresh, disconnected value.
    private nonisolated static func encode(_ args: BackendArgs) -> [String: ConvexEncodable?] {
        args.mapValues { value -> ConvexEncodable? in
            switch value {
            case .string(let string): string
            case .int(let int): int
            case .double(let double): double
            case .bool(let bool): bool
            case .null: nil
            }
        }
    }

    /// Used when `FEATURE_AUTH` is off: Convex still connects, just anonymously.
    private final class AnonymousAuthProvider: AuthProvider {
        typealias T = String

        func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> String {
            throw BackendError.notConfigured
        }

        func loginFromCache(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> String {
            throw BackendError.notConfigured
        }

        func logout() async throws {}

        func extractIdToken(from authResult: String) -> String { authResult }
    }
    #endif
}

#if canImport(ConvexMobile)
/// Carries a Combine subscription across the `@Sendable` boundary of
/// `AsyncThrowingStream.onTermination`. `AnyCancellable` isn't `Sendable`, and
/// cancelling it from another thread is safe once the access is locked.
private final class CancellableBox: @unchecked Sendable {
    private let lock = NSLock()
    private var cancellable: AnyCancellable?
    private var isCancelled = false

    func store(_ value: AnyCancellable) {
        lock.lock()
        defer { lock.unlock() }
        // The stream can terminate before `sink` returns; honour that.
        if isCancelled {
            value.cancel()
        } else {
            cancellable = value
        }
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = true
        cancellable?.cancel()
        cancellable = nil
    }
}
#endif

extension AsyncThrowingStream where Failure == Error {
    /// A stream that immediately fails. Keeps the "not configured" path in the
    /// same shape as the happy path, so views need one error branch, not two.
    static func failing(with error: Error) -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}
