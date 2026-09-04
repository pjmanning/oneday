import SwiftUI

/// Design tokens.
///
/// Deliberately small. The iOS 26 system look — Liquid Glass chrome, grouped
/// lists, standard toolbars — does most of the work, so the job here is
/// consistent spacing and one accent colour, not a parallel design language.
///
/// **Colour rule:** exactly one brand token (`AccentColor` in the asset
/// catalog). Everything else is a semantic system colour so light mode, dark
/// mode, Increase Contrast and Reduce Transparency all keep working for free.
enum Theme {

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Layout {
        /// Keeps text measures readable on iPad without a separate layout.
        static let maxContentWidth: CGFloat = 560
        static let controlHeight: CGFloat = 50
        static let avatarSize: CGFloat = 72
    }

    /// The single brand colour. Edit `Resources/Assets.xcassets/AccentColor`
    /// (both light and dark variants) to rebrand the whole app.
    static let accent = Color.accentColor
}

extension View {
    /// Constrains a column of content and centres it — the default for the
    /// scrolling screens in this kit.
    func readableContentColumn() -> some View {
        frame(maxWidth: Theme.Layout.maxContentWidth)
            .frame(maxWidth: .infinity)
    }
}
