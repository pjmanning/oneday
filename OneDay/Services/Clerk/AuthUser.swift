import Foundation

/// Where the session currently stands. `Features/` code branches on this and
/// never touches ClerkKit directly.
enum AuthState: Hashable, Sendable {
    /// Clerk is restoring a cached session. Show the launch view, not sign-in.
    case loading
    case signedOut
    case signedIn
}

/// A Clerk user flattened into something the UI can render.
///
/// Keeping this struct between ClerkKit and `Features/` means swapping auth
/// providers is a job for `Services/Clerk/` alone.
struct AuthUser: Hashable, Identifiable, Sendable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String?
    let imageURL: URL?

    var displayName: String {
        let name = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !name.isEmpty { return name }
        if let email, !email.isEmpty { return email }
        return "Signed in"
    }

    /// Fallback for the avatar when the user has no profile image.
    var initials: String {
        let letters = [firstName, lastName]
            .compactMap { $0?.first }
            .map(String.init)
        if !letters.isEmpty { return letters.joined().uppercased() }
        if let first = email?.first { return String(first).uppercased() }
        return "?"
    }
}

extension AuthUser {
    /// Stand-in used when Clerk has no publishable key yet, so the shell is
    /// still explorable on a fresh clone. See `AuthService.signInAsPreviewUser`.
    static let preview = AuthUser(
        id: "preview-user",
        firstName: "Preview",
        lastName: "User",
        email: "preview@example.com",
        imageURL: nil
    )
}
