import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

@MainActor
final class PurchaseService: ObservableObject {
    @Published var isConfigured = false
    @Published var packages: [String] = ["Monthly $9.99", "Yearly $59.99", "Lifetime $149.99"]
    @Published var entitlementActive = false
    @Published var activeProductIdentifier: String?
    @Published var activePlanLabel: String?
    @Published var lastError: String?
    @Published var isLoadingOfferings = false
    @Published var hasLoadedStoreProducts = false

    #if DEBUG
    private let publicAPIKey: String? = "appl_GgMgjtcGivuXQISIAIccPuUwdSr"
    #else
    private let publicAPIKey: String? = "appl_GgMgjtcGivuXQISIAIccPuUwdSr"
    #endif
    #if canImport(RevenueCat)
    private var revenueCatPackages: [String: Package] = [:]
    private var packageProductIdentifiers: [String: String] = [:]
    private var configuredAppUserId: String?
    #endif

    func configure(appUserId: String?) {
        guard let publicAPIKey else {
            isConfigured = false
            lastError = "Purchases are temporarily unavailable."
            return
        }
        #if canImport(RevenueCat)
        if isConfigured {
            return
        }
        Purchases.configure(withAPIKey: publicAPIKey, appUserID: appUserId)
        configuredAppUserId = appUserId
        #endif
        isConfigured = true
    }

    func identify(appUserId: String?) async {
        configure(appUserId: appUserId)
        #if canImport(RevenueCat)
        guard let appUserId else {
            await refreshCustomerInfo()
            return
        }
        guard configuredAppUserId != appUserId else {
            await refreshCustomerInfo()
            return
        }
        do {
            let result = try await Purchases.shared.logIn(appUserId)
            configuredAppUserId = appUserId
            applyCustomerInfo(result.customerInfo)
            lastError = nil
        } catch {
            lastError = "Could not refresh Premium access."
        }
        #endif
    }

    func refreshCustomerInfo() async {
        guard isConfigured else { return }
        #if canImport(RevenueCat)
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
            lastError = nil
        } catch {
            lastError = "Could not refresh Premium access."
        }
        #endif
    }

    func loadOfferings() async {
        guard isConfigured else {
            if publicAPIKey == nil {
                lastError = "Purchases are temporarily unavailable."
            }
            return
        }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }

        #if canImport(RevenueCat)
        do {
            let offerings = try await withTimeout(seconds: 8) {
                try await Purchases.shared.offerings()
            }
            guard let offering = offerings.offering(identifier: "default") ?? offerings.current else {
                hasLoadedStoreProducts = false
                lastError = "Plans are temporarily unavailable. Please try again shortly."
                return
            }
            let loaded = offering.availablePackages
            guard loaded.isEmpty == false else {
                hasLoadedStoreProducts = false
                lastError = "Plans are temporarily unavailable. Please try again shortly."
                return
            }
            revenueCatPackages = Dictionary(uniqueKeysWithValues: loaded.map { package in
                let label = packageLabel(package)
                return (label, package)
            })
            packageProductIdentifiers = Dictionary(uniqueKeysWithValues: loaded.map { package in
                let label = packageLabel(package)
                return (label, package.storeProduct.productIdentifier)
            })
            activePlanLabel = activeProductIdentifier.flatMap(planLabel(for:))
            packages = loaded.map(packageLabel)
            hasLoadedStoreProducts = true
            lastError = nil
        } catch {
            hasLoadedStoreProducts = false
            lastError = "Plans are temporarily unavailable. Please try again shortly."
        }
        #endif
    }

    func restore() async {
        guard isConfigured else {
            lastError = "Purchases are temporarily unavailable."
            return
        }
        #if canImport(RevenueCat)
        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)
            lastError = entitlementActive ? nil : "No previous Premium purchase was found for this Apple Account."
        } catch {
            lastError = error.localizedDescription
        }
        #else
        entitlementActive = true
        #endif
    }

    func purchase(package label: String) async {
        guard isConfigured else {
            lastError = "Purchases are temporarily unavailable."
            return
        }
        #if canImport(RevenueCat)
        guard let package = revenueCatPackages[label] else {
            lastError = "Plans are still refreshing. Please try again shortly."
            return
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            applyCustomerInfo(result.customerInfo)
            if entitlementActive == false {
                await refreshCustomerInfo()
            }
            lastError = entitlementActive ? nil : "Upgrade is processing. Please try Restore if Premium does not activate shortly."
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
        }
        #else
        entitlementActive = true
        lastError = "Preview purchase active for \(label)."
        #endif
    }

    func startPreviewPurchase(package: String) {
        entitlementActive = true
        lastError = "Preview purchase active for \(package)."
    }

    func clearLocalEntitlementState() {
        entitlementActive = false
        activeProductIdentifier = nil
        activePlanLabel = nil
        lastError = nil
        isLoadingOfferings = false
        hasLoadedStoreProducts = false
        #if canImport(RevenueCat)
        revenueCatPackages = [:]
        packageProductIdentifiers = [:]
        #endif
    }

    #if canImport(RevenueCat)
    private func withTimeout<T: Sendable>(
        seconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw TimeoutError()
            }
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            group.cancelAll()
            return result
        }
    }

    private struct TimeoutError: Error {}

    func isActivePackage(_ label: String) -> Bool {
        guard entitlementActive, let activeProductIdentifier else { return false }
        return packageProductIdentifiers[label] == activeProductIdentifier
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        if let entitlement = info.entitlements["premium"], entitlement.isActive {
            entitlementActive = true
            activeProductIdentifier = entitlement.productIdentifier
            activePlanLabel = planLabel(for: entitlement.productIdentifier)
        } else {
            entitlementActive = false
            activeProductIdentifier = nil
            activePlanLabel = nil
        }
    }

    private func planLabel(for productId: String) -> String {
        if productId.contains("yearly") || productId == "yearly" {
            return "Yearly"
        }
        if productId.contains("monthly") || productId == "monthly" {
            return "Monthly"
        }
        if productId.contains("lifetime") || productId == "lifetime" {
            return "Lifetime"
        }
        return "Premium"
    }

    private func packageLabel(_ package: Package) -> String {
        let productId = package.storeProduct.productIdentifier

        if productId.contains("yearly") || productId == "yearly" {
            return "Yearly $59.99"
        }
        if productId.contains("monthly") || productId == "monthly" {
            return "Monthly $9.99"
        }
        if productId.contains("lifetime") || productId == "lifetime" {
            return "Lifetime $149.99"
        }
        let title = package.storeProduct.localizedTitle
        let price = package.storeProduct.localizedPriceString
        return title.isEmpty ? "\(package.identifier) \(price)" : "\(title) \(price)"
    }
    #endif
}
