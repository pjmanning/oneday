import Foundation

/// Every event the app sends, in one enum.
enum AnalyticsEvent: Sendable {
    case appLaunched
    case onboardingStarted
    case onboardingSkipped(page: Int)
    case onboardingCompleted
    case authSucceeded(method: String)
    case signedOut
    case accountDeleted
    case paywallShown(source: String)
    case paywallDismissed(source: String)
    case purchaseCompleted(productID: String)
    case purchasesRestored
    case premiumFeatureBlocked(feature: String)
    case oneDayPublished(durationSeconds: Int)
    case followingCapChanged(mode: String)
    case billingOpened
    case feedbackPortalOpened(kind: String)
    case pushPermissionAnswered(granted: Bool)

    var name: String {
        switch self {
        case .appLaunched: "app_launched"
        case .onboardingStarted: "onboarding_started"
        case .onboardingSkipped: "onboarding_skipped"
        case .onboardingCompleted: "onboarding_completed"
        case .authSucceeded: "auth_succeeded"
        case .signedOut: "signed_out"
        case .accountDeleted: "account_deleted"
        case .paywallShown: "paywall_shown"
        case .paywallDismissed: "paywall_dismissed"
        case .purchaseCompleted: "purchase_completed"
        case .purchasesRestored: "purchases_restored"
        case .premiumFeatureBlocked: "premium_feature_blocked"
        case .oneDayPublished: "oneday_published"
        case .followingCapChanged: "following_cap_changed"
        case .billingOpened: "billing_opened"
        case .feedbackPortalOpened: "feedback_portal_opened"
        case .pushPermissionAnswered: "push_permission_answered"
        }
    }

    var properties: [String: String] {
        switch self {
        case .onboardingSkipped(let page): ["page": String(page)]
        case .authSucceeded(let method): ["method": method]
        case .paywallShown(let source), .paywallDismissed(let source): ["source": source]
        case .purchaseCompleted(let productID): ["product_id": productID]
        case .premiumFeatureBlocked(let feature): ["feature": feature]
        case .oneDayPublished(let durationSeconds): ["duration_seconds": String(durationSeconds)]
        case .followingCapChanged(let mode): ["mode": mode]
        case .feedbackPortalOpened(let kind): ["kind": kind]
        case .pushPermissionAnswered(let granted): ["granted": String(granted)]
        default: [:]
        }
    }
}
