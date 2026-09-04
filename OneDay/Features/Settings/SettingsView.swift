import SwiftUI

/// Privacy, following caps, legal, and diagnostics.
struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(RootRouter.self) private var router
    @Environment(FollowingCapsStore.self) private var caps
    @Environment(DailyPostLock.self) private var dailyLock

    @State private var hasOptedOutOfAnalytics = Analytics.hasOptedOut
    @State private var isConfirmingSignOut = false

    var body: some View {
        @Bindable var caps = caps

        NavigationStack {
            List {
                followingCapSection(caps: caps)
                privacySection
                legalSection

                #if DEBUG
                diagnosticsSection
                #endif

                accountSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
        .confirmationDialog("Sign out?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    await auth.signOut()
                    Analytics.track(.signedOut)
                    Analytics.reset()
                }
            }
        }
        .accessibilityIdentifier("settings")
    }

    private func followingCapSection(caps: FollowingCapsStore) -> some View {
        @Bindable var caps = caps
        return Section {
            Picker("Following limit", selection: $caps.mode) {
                ForEach(FollowingCapMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .accessibilityIdentifier("settings.followingCap")
            .onChange(of: caps.mode) { _, newMode in
                Analytics.track(.followingCapChanged(mode: newMode.rawValue))
            }

            LabeledContent("Status", value: caps.statusSummary)
                .accessibilityIdentifier("settings.capStatus")

            #if DEBUG
            Button("Stub: follow +1") {
                _ = caps.tryFollow()
            }
            .accessibilityIdentifier("settings.stubFollow")

            Button("Stub: watch +1 min") {
                _ = caps.recordWatchMinute()
            }
            .accessibilityIdentifier("settings.stubWatch")

            Button("Reset cap stubs", role: .destructive) {
                caps.resetStubs()
            }
            .accessibilityIdentifier("settings.resetCaps")
            #endif
        } header: {
            Text("Following cap")
        } footer: {
            Text(caps.mode.detail + " Both options are stubbed locally until the backend enforces them.")
        }
    }

    private var privacySection: some View {
        Section {
            Toggle("Share anonymous usage data", isOn: $hasOptedOutOfAnalytics.inverted)
                .accessibilityIdentifier("settings.analyticsToggle")
                .onChange(of: hasOptedOutOfAnalytics) { _, newValue in
                    Analytics.hasOptedOut = newValue
                }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Usage data helps us find crashes and dead ends. It never includes your clips.")
        }
    }

    private var legalSection: some View {
        Section("Legal") {
            if let privacy = AppConfig.privacyPolicyURL {
                Link("Privacy Policy", destination: privacy)
                    .accessibilityIdentifier("settings.privacyPolicy")
            }
            if let terms = AppConfig.termsURL {
                Link("Terms of Service", destination: terms)
                    .accessibilityIdentifier("settings.terms")
            }
            if let email = AppConfig.supportEmail, let url = URL(string: "mailto:\(email)") {
                Link("Contact support", destination: url)
                    .accessibilityIdentifier("settings.support")
            }
        }
    }

    #if DEBUG
    private var diagnosticsSection: some View {
        Section {
            Button("Reset onboarding") {
                router.resetFirstRunState()
            }
            .accessibilityIdentifier("settings.resetFirstRun")

            Button("Clear today's post lock") {
                dailyLock.clear()
            }
            .accessibilityIdentifier("settings.clearPostLock")

            NavigationLink("Feature flags") {
                FeatureFlagsDebugView()
            }
            .accessibilityIdentifier("settings.featureFlags")

            if !AppConfig.unconfiguredKeys.isEmpty {
                LabeledContent("Unconfigured keys", value: "\(AppConfig.unconfiguredKeys.count)")
            }
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("DEBUG builds only — this section is compiled out of Release.")
        }
    }
    #endif

    private var accountSection: some View {
        Section {
            Button("Sign out") { isConfirmingSignOut = true }
                .accessibilityIdentifier("settings.signOut")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: AppConfig.versionDisplay)
                .accessibilityIdentifier("settings.version")
        } footer: {
            Text("OneDay · one post a day · respect your time")
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private extension Binding where Value == Bool {
    var inverted: Binding<Bool> {
        Binding<Bool>(
            get: { !wrappedValue },
            set: { wrappedValue = !$0 }
        )
    }
}

#if DEBUG
private struct FeatureFlagsDebugView: View {
    var body: some View {
        List {
            Section {
                ForEach(FeatureFlags.all, id: \.name) { flag in
                    LabeledContent(flag.name) {
                        Image(systemName: flag.isOn ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(flag.isOn ? Color.green : Color.secondary)
                    }
                }
            } footer: {
                Text("Edit FEATURE_FLAGS in Config/Base.xcconfig to change these.")
            }
        }
        .navigationTitle("Feature flags")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
