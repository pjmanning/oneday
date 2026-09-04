import SwiftUI

/// The illustration at the top of an onboarding page — animated SF Symbol.
struct OnboardingArtwork: View {
    let page: OnboardingPage

    var body: some View {
        Image(systemName: page.systemImage)
            .font(.system(size: 96, weight: .light))
            .foregroundStyle(Theme.accent.gradient)
            .symbolEffect(.bounce, options: .nonRepeating)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .accessibilityHidden(true)
    }
}
