import SwiftUI

/// Identity, today's OneDay status, and following-cap summary.
struct ProfileView: View {
    @Environment(AuthService.self) private var auth
    @Environment(DailyPostLock.self) private var dailyLock
    @Environment(FollowingCapsStore.self) private var caps

    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDelete = false
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            List {
                identitySection
                todaySection
                followingSection
                accountSection
            }
            .navigationTitle("Profile")
        }
        .confirmationDialog("Sign out?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await signOut() }
            }
        }
        .alert("Delete your account?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This permanently deletes your account and its data. It cannot be undone.")
        }
        .disabled(isWorking)
        .accessibilityIdentifier("profile")
    }

    private var identitySection: some View {
        Section {
            HStack(spacing: Theme.Spacing.md) {
                avatar

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(auth.user?.displayName ?? "Not signed in")
                        .font(.title3.weight(.semibold))
                    if let email = auth.user?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("profile.identity")
        }
    }

    private var avatar: some View {
        Group {
            if let url = auth.user?.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsAvatar
                }
            } else {
                initialsAvatar
            }
        }
        .frame(width: Theme.Layout.avatarSize, height: Theme.Layout.avatarSize)
        .clipShape(.circle)
    }

    private var initialsAvatar: some View {
        ZStack {
            Circle().fill(Theme.accent.gradient)
            Text(auth.user?.initials ?? "?")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var todaySection: some View {
        Section("Today") {
            LabeledContent("OneDay") {
                Text(dailyLock.hasPostedToday ? "Published" : "Not yet")
                    .foregroundStyle(dailyLock.hasPostedToday ? Color.green : Color.secondary)
            }
            .accessibilityIdentifier("profile.todayStatus")

            Text("One post per day. One headline. 1–3 minutes. No links.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var followingSection: some View {
        Section("Respecting time") {
            LabeledContent("Cap", value: caps.mode.title)
                .accessibilityIdentifier("profile.capMode")
            LabeledContent("Status", value: caps.statusSummary)
                .accessibilityIdentifier("profile.capStatus")

            Text("Change the following cap in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var accountSection: some View {
        Section {
            Button("Sign out") {
                isConfirmingSignOut = true
            }
            .accessibilityIdentifier("profile.signOut")

            Button("Delete account", role: .destructive) {
                isConfirmingDelete = true
            }
            .accessibilityIdentifier("profile.deleteAccount")
        } footer: {
            Text("Deleting your account removes it from Clerk.")
        }
    }

    private func signOut() async {
        isWorking = true
        defer { isWorking = false }
        await auth.signOut()
        Analytics.track(.signedOut)
        Analytics.reset()
        ErrorReporting.setUser(id: nil, email: nil)
    }

    private func deleteAccount() async {
        isWorking = true
        defer { isWorking = false }
        await auth.deleteAccount()
        Analytics.track(.accountDeleted)
        Analytics.reset()
        ErrorReporting.setUser(id: nil, email: nil)
    }
}
