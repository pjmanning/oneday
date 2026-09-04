import Foundation

#if canImport(RevenueCat) && FEATURE_PAYWALL
import RevenueCat
#endif

/// RevenueCat + StoreKit 2: offerings, purchase, restore, and the `isPremium`
/// flag the rest of the app gates on.
///
/// RevenueCat is for **App Store in-app purchases** — the required path for
/// digital goods on iOS. It is not the same thing as `BillingService`, which
/// reads Stripe records for purchases made on the web. See docs/ARCHITECTURE.md.
@MainActor
@Observable
final class PurchaseService {

    /// The entitlement identifier configured in the RevenueCat dashboard.
    /// Change it here if you named yours something else.
    static let premiumEntitlementID = "premium"

    /// One purchasable option, flattened for the paywall UI.
    struct Product: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let detail: String
        let priceString: String
        /// e.g. "per month". Empty for lifetime / consumable products.
        let periodDescription: String
        let isRecommended: Bool
    }

    enum LoadState: Hashable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var isPremium = false
    private(set) var products: [Product] = []
    private(set) var state: LoadState = .idle
    private(set) var isPurchasing = false

    /// Human-readable subscription status for Profile, e.g. "Premium · renews 3 Sep 2026".
    private(set) var subscriptionSummary: String?

    let isConfigured: Bool = AppConfig.revenueCatAPIKey != nil && FeatureFlags.paywall

    #if canImport(RevenueCat) && FEATURE_PAYWALL
    private var packagesByProductID: [String: Package] = [:]
    private var customerInfoTask: Task<Void, Never>?
    #endif

    // MARK: - Lifecycle

    func start() {
        guard FeatureFlags.paywall else { return }
        guard let apiKey = AppConfig.revenueCatAPIKey else {
            Log.paywall.warning(
                "RevenueCat is not configured — set REVENUECAT_API_KEY in Config/Secrets.xcconfig. The paywall will show a setup message."
            )
            return
        }

        #if canImport(RevenueCat) && FEATURE_PAYWALL
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)

        // Entitlements can change without user action (renewal, refund, family
        // sharing), so follow the stream rather than fetching once.
        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        #else
        Log.paywall.debug("RevenueCat is not linked — purchases are disabled.")
        #endif
    }

    /// Ties purchases to the signed-in user so entitlements follow them across
    /// devices. Call on sign-in; call `logOutUser()` on sign-out.
    func setUserID(_ id: String) async {
        guard isConfigured else { return }
        #if canImport(RevenueCat) && FEATURE_PAYWALL
        do {
            let (info, _) = try await Purchases.shared.logIn(id)
            apply(info)
        } catch {
            ErrorReporting.capture(error, context: "revenuecat.logIn")
        }
        #endif
    }

    func logOutUser() async {
        guard isConfigured else { return }
        #if canImport(RevenueCat) && FEATURE_PAYWALL
        do {
            let info = try await Purchases.shared.logOut()
            apply(info)
        } catch {
            ErrorReporting.capture(error, context: "revenuecat.logOut")
        }
        #endif
    }

    // MARK: - Offerings

    func loadProducts() async {
        guard isConfigured else {
            state = .failed(
                "RevenueCat isn't configured yet. Set REVENUECAT_API_KEY in Config/Secrets.xcconfig and create an offering in the RevenueCat dashboard."
            )
            return
        }

        state = .loading

        #if canImport(RevenueCat) && FEATURE_PAYWALL
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else {
                state = .failed("No current offering. Mark one as Current in the RevenueCat dashboard.")
                return
            }

            packagesByProductID = Dictionary(
                offering.availablePackages.map { ($0.storeProduct.productIdentifier, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            products = offering.availablePackages.map { package in
                Product(
                    id: package.storeProduct.productIdentifier,
                    title: package.storeProduct.localizedTitle,
                    detail: package.storeProduct.localizedDescription,
                    priceString: package.storeProduct.localizedPriceString,
                    periodDescription: Self.periodDescription(for: package),
                    isRecommended: package.packageType == .annual
                )
            }
            state = products.isEmpty
                ? .failed("The current offering has no packages attached.")
                : .loaded
        } catch {
            ErrorReporting.capture(error, context: "revenuecat.offerings")
            state = .failed(error.localizedDescription)
        }
        #else
        state = .failed("The RevenueCat package isn't linked in this build.")
        #endif
    }

    // MARK: - Purchase / restore

    /// - Returns: `true` when the user ends up entitled.
    @discardableResult
    func purchase(productID: String) async -> Bool {
        guard isConfigured else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        #if canImport(RevenueCat) && FEATURE_PAYWALL
        guard let package = packagesByProductID[productID] else {
            state = .failed("That product is no longer in the current offering.")
            return false
        }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return false }
            apply(result.customerInfo)
            if isPremium {
                Analytics.track(.purchaseCompleted(productID: productID))
            }
            return isPremium
        } catch {
            ErrorReporting.capture(error, context: "revenuecat.purchase")
            state = .failed(error.localizedDescription)
            return false
        }
        #else
        return false
        #endif
    }

    /// Required by App Store review whenever you sell subscriptions.
    @discardableResult
    func restorePurchases() async -> Bool {
        guard isConfigured else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        #if canImport(RevenueCat) && FEATURE_PAYWALL
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            Analytics.track(.purchasesRestored)
            return isPremium
        } catch {
            ErrorReporting.capture(error, context: "revenuecat.restore")
            state = .failed(error.localizedDescription)
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Internals

    #if canImport(RevenueCat) && FEATURE_PAYWALL
    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[Self.premiumEntitlementID]
        isPremium = entitlement?.isActive == true

        guard let entitlement, entitlement.isActive else {
            subscriptionSummary = nil
            return
        }

        if let expiry = entitlement.expirationDate {
            let date = expiry.formatted(date: .abbreviated, time: .omitted)
            subscriptionSummary = entitlement.willRenew ? "Renews \(date)" : "Expires \(date)"
        } else {
            subscriptionSummary = "Lifetime"
        }
    }

    private static func periodDescription(for package: Package) -> String {
        guard let period = package.storeProduct.subscriptionPeriod else { return "" }
        let unit = switch period.unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        @unknown default: "period"
        }
        return period.value == 1 ? "per \(unit)" : "per \(period.value) \(unit)s"
    }
    #endif
}
