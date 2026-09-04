import SwiftUI

/// The signed-out gate: Sign in with Apple and Sign in with Google, both via Clerk.
///
/// Clerk presents its own system sheets, so this screen owns nothing but the
/// two buttons, the error line and the legal footer.
struct AuthView: View {
    @Environment(AuthService.self) private var auth

    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    Spacer(minLength: Theme.Spacing.xxl)

                    header

                    if !auth.isConfigured {
                        unconfiguredNotice
                    }

                    signInButtons

                    if let error = auth.lastErrorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("auth.error")
                    }

                    legalFooter

                    Spacer(minLength: Theme.Spacing.xl)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .readableContentColumn()
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(.systemGroupedBackground))
        }
        .accessibilityIdentifier("auth")
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "swift")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(Theme.accent.gradient)

            Text("Welcome to \(AppConfig.displayName)")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Sign in to sync your data across devices.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var signInButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                Task { await run { await auth.signInWithApple() } }
            } label: {
                providerLabel("Sign in with Apple", systemImage: "apple.logo")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.label))
            .buttonBorderShape(.roundedRectangle(radius: Theme.Radius.md))
            .accessibilityIdentifier("auth.apple")

            Button {
                Task { await run { await auth.signInWithGoogle() } }
            } label: {
                providerLabel("Sign in with Google", systemImage: "g.circle.fill")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: Theme.Radius.md))
            .accessibilityIdentifier("auth.google")

            if !auth.isConfigured {
                // Only reachable while Clerk has no publishable key, so it
                // cannot survive into a configured build.
                Button("Explore without signing in") {
                    auth.signInAsPreviewUser()
                }
                .font(.footnote)
                .padding(.top, Theme.Spacing.xs)
                .accessibilityIdentifier("auth.previewUser")
            }
        }
        .disabled(isWorking)
        .overlay {
            if isWorking {
                ProgressView().controlSize(.large)
            }
        }
    }

    private func providerLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .frame(height: Theme.Layout.controlHeight)
    }

    private var unconfiguredNotice: some View {
        SetupRequiredRow(integration: "Clerk", settingName: "CLERK_PUBLISHABLE_KEY")
            .padding(Theme.Spacing.md)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.Radius.md))
    }

    private var legalFooter: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text("By continuing you agree to our")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: Theme.Spacing.xs) {
                if let terms = AppConfig.termsURL {
                    Link("Terms", destination: terms)
                }
                if AppConfig.termsURL != nil && AppConfig.privacyPolicyURL != nil {
                    Text("·").foregroundStyle(.secondary)
                }
                if let privacy = AppConfig.privacyPolicyURL {
                    Link("Privacy Policy", destination: privacy)
                }
            }
            .font(.caption)
        }
    }

    private func run(_ work: () async -> Void) async {
        isWorking = true
        await work()
        isWorking = false
    }
}

#Preview {
    AuthView()
        .environment(AuthService())
}
