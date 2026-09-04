import SwiftUI

/// Compose today's OneDay — locked after one successful publish per day.
struct ComposerView: View {
    @Environment(BackendService.self) private var backend
    @Environment(DailyPostLock.self) private var dailyLock
    @Environment(\.dismiss) private var dismiss

    @State private var model = ComposerViewModel()

    var body: some View {
        NavigationStack {
            Form {
                if dailyLock.hasPostedToday {
                    Section {
                        Label(dailyLock.lockMessage, systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("composer.locked")
                    }
                }

                Section {
                    TextField("One headline", text: $model.headline, axis: .vertical)
                        .lineLimit(2...3)
                        .disabled(dailyLock.hasPostedToday)
                        .accessibilityIdentifier("composer.headline")
                } header: {
                    Text("Headline")
                } footer: {
                    Text("No external links. Say it in the clip.")
                }

                Section {
                    Stepper(
                        value: $model.durationSeconds,
                        in: ComposerViewModel.minDurationSeconds...ComposerViewModel.maxDurationSeconds,
                        step: 15
                    ) {
                        Text("\(model.durationSeconds / 60)m \(model.durationSeconds % 60)s")
                    }
                    .disabled(dailyLock.hasPostedToday)
                    .accessibilityIdentifier("composer.duration")
                } header: {
                    Text("Length (1–3 min)")
                }

                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Label("Clip", systemImage: "video")
                            .font(.headline)
                        Text("Video capture is stubbed. Duration above is the contract for the eventual recorder.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    .accessibilityIdentifier("composer.clipStub")
                }

                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Label("AI summary", systemImage: "sparkles")
                            .font(.headline)
                        Text("After publish, a short summary of the clip will generate here. Placeholder for now.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    .accessibilityIdentifier("composer.aiStub")
                }

                if let hint = model.validationHint, !dailyLock.hasPostedToday {
                    Section {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Today's OneDay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("composer.close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        Task {
                            await model.publish(using: backend, lock: dailyLock)
                            if model.didPublish { dismiss() }
                        }
                    }
                    .disabled(!model.canPublish || dailyLock.hasPostedToday)
                    .accessibilityIdentifier("composer.publish")
                }
            }
            .alert(
                "Couldn't publish",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                ),
                presenting: model.errorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
        .accessibilityIdentifier("composer")
    }
}
