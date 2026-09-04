import SwiftUI

/// The tabs of the main shell.
///
/// Cases appear and disappear with the `FEATURE_*` tokens in
/// `Config/Base.xcconfig`, which is what lets you delete a whole
/// `Features/<Name>/` folder without touching the router.
///
/// At least one tab must remain — see `AppTab.initial`.
enum AppTab: Hashable, Identifiable, CaseIterable {
    #if FEATURE_HOME
    case home
    #endif
    #if FEATURE_PROFILE
    case profile
    #endif
    #if FEATURE_SETTINGS
    case settings
    #endif

    var id: String {
        switch self {
        #if FEATURE_HOME
        case .home: "home"
        #endif
        #if FEATURE_PROFILE
        case .profile: "profile"
        #endif
        #if FEATURE_SETTINGS
        case .settings: "settings"
        #endif
        }
    }

    var title: LocalizedStringKey {
        switch self {
        #if FEATURE_HOME
        case .home: "Feed"
        #endif
        #if FEATURE_PROFILE
        case .profile: "Profile"
        #endif
        #if FEATURE_SETTINGS
        case .settings: "Settings"
        #endif
        }
    }

    var systemImage: String {
        switch self {
        #if FEATURE_HOME
        case .home: "rectangle.stack"
        #endif
        #if FEATURE_PROFILE
        case .profile: "person.crop.circle"
        #endif
        #if FEATURE_SETTINGS
        case .settings: "gearshape"
        #endif
        }
    }

    /// The tab shown on first launch. Resolved at compile time so it stays
    /// valid whichever features you keep.
    static var initial: AppTab {
        #if FEATURE_HOME
        .home
        #elseif FEATURE_PROFILE
        .profile
        #elseif FEATURE_SETTINGS
        .settings
        #else
        #error("Keep at least one of FEATURE_HOME / FEATURE_PROFILE / FEATURE_SETTINGS in FEATURE_FLAGS (Config/Base.xcconfig) — the app needs a tab to show.")
        #endif
    }
}
