import SwiftUI

/// Content for one onboarding page.
struct OnboardingPage: Identifiable, Sendable {
    let id: Int
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String
    let lottieName: String?

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            title: "One post a day",
            message: "Share a 1–3 minute clip with a single headline. No links. No spam. Show up once.",
            systemImage: "sun.max.fill",
            lottieName: nil
        ),
        OnboardingPage(
            id: 1,
            title: "Respect your time",
            message: "Follow at most 30 people — or cap yourself at 30 minutes a day. You choose the limit.",
            systemImage: "hourglass",
            lottieName: nil
        ),
        OnboardingPage(
            id: 2,
            title: "Know it in a glance",
            message: "Every clip gets an AI summary so you can decide if it's worth your minutes.",
            systemImage: "sparkles",
            lottieName: nil
        ),
    ]
}
