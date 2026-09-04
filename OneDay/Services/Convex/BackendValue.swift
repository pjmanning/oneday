import Foundation

/// A Convex function argument, in a form `Features/` can build without
/// importing ConvexMobile.
///
/// Add a case here (and its mapping in `BackendService`) if you need a type
/// that isn't covered — that keeps the ConvexMobile import inside
/// `Services/Convex/`, which is the whole point of this indirection.
enum BackendValue: Hashable, Sendable, ExpressibleByStringLiteral {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(stringLiteral value: String) {
        self = .string(value)
    }
}

/// Named arguments for a Convex query, mutation, or action.
typealias BackendArgs = [String: BackendValue]

/// What went wrong talking to Convex, in terms the UI can show a user.
enum BackendError: LocalizedError {
    /// `CONVEX_DEPLOYMENT_URL` is still `REPLACE_ME`.
    case notConfigured
    /// The ConvexMobile package isn't linked in this build.
    case clientUnavailable
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Convex isn't configured yet. Run `npx convex dev` and set CONVEX_DEPLOYMENT_URL in Config/Secrets.xcconfig."
        case .clientUnavailable:
            "The Convex client isn't linked in this build. Add the convex-swift package in Xcode."
        case .transport(let message):
            message
        }
    }
}
