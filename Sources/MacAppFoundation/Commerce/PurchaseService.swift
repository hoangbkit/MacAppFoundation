import Foundation
import OSLog
import StoreKit

@MainActor
protocol PurchaseServing: AnyObject {
    func products(for identifiers: [String]) async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> PurchaseOutcome
    /// Returns only records the backing store currently considers entitled.
    /// Consumers must not independently expire these records after they are returned.
    func currentEntitlements() async -> [EntitlementRecord]
    func entitlementContext() -> PurchaseEntitlementContext?
    func latestEntitlement(for productID: String) async -> LatestEntitlementLookup
    func entitlementUpdates(for productIDs: Set<String>) -> AsyncStream<String>
    func subscriptionStatusUpdates(for productIDs: Set<String>) -> AsyncStream<String>
    func sync() async throws
}

extension PurchaseServing {
    func entitlementContext() -> PurchaseEntitlementContext? {
        nil
    }

    func latestEntitlement(for productID: String) async -> LatestEntitlementLookup {
        .unavailable
    }
}

@MainActor
final class LiveStoreKitService: PurchaseServing {
    private static let logger = Logger(
        subsystem: "com.macappfoundation.purchases",
        category: "storekit"
    )

    private var productsByID: [String: Product] = [:]

    init() {}

    func products(for identifiers: [String]) async throws -> [StoreProduct] {
        let products = try await Product.products(for: identifiers)
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        var storeProducts: [StoreProduct] = []
        storeProducts.reserveCapacity(products.count)
        for product in products {
            storeProducts.append(await Self.makeStoreProduct(product))
        }
        return storeProducts
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        let product: Product
        if let cachedProduct = productsByID[productID] {
            product = cachedProduct
        } else if let fetchedProduct = try await Product.products(for: [productID]).first {
            productsByID[productID] = fetchedProduct
            product = fetchedProduct
        } else {
            throw PurchaseFailure.productUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.verified(verification)
            let record = await Self.makeEntitlementRecord(transaction)
            await transaction.finish()
            return .success(record)
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        @unknown default:
            throw PurchaseFailure.unknown
        }
    }

    func currentEntitlements() async -> [EntitlementRecord] {
        var records: [EntitlementRecord] = []

        for await verification in Transaction.currentEntitlements {
            switch verification {
            case .verified(let transaction):
                records.append(await Self.makeEntitlementRecord(transaction))
            case .unverified(_, let error):
                Self.logger.warning(
                    "Skipping unverified StoreKit entitlement: \(String(describing: error), privacy: .public)"
                )
            }
        }

        return records
    }

    func entitlementContext() -> PurchaseEntitlementContext? {
        switch AppTransaction.shared {
        case .verified(let appTransaction):
            return PurchaseEntitlementContext(
                bundleID: appTransaction.bundleID,
                environment: Self.makeEnvironment(appTransaction.environment),
                appTransactionID: appTransaction.appTransactionID
            )
        case .unverified(_, let error):
            Self.logger.warning(
                "Unable to verify AppTransaction for entitlement cache: \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func latestEntitlement(for productID: String) async -> LatestEntitlementLookup {
        guard let result = await Transaction.latest(for: productID) else {
            return .notPurchased
        }

        switch result {
        case .verified(let transaction):
            return .verified(await Self.makeEntitlementRecord(transaction))
        case .unverified(_, let error):
            Self.logger.warning(
                "Unable to verify latest StoreKit transaction for cached entitlement: \(String(describing: error), privacy: .public)"
            )
            return .unavailable
        }
    }

    /// Observes only transactions owned by this purchase manager.
    /// Unknown transactions are deliberately left unfinished so another StoreKit
    /// subsystem can deliver its content and finish them itself.
    func entitlementUpdates(for productIDs: Set<String>) -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task {
                for await verification in Transaction.updates {
                    guard !Task.isCancelled else {
                        break
                    }

                    guard case .verified(let transaction) = verification,
                          productIDs.contains(transaction.productID)
                    else {
                        continue
                    }

                    await transaction.finish()
                    continuation.yield(transaction.productID)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Observes subscription lifecycle changes without finishing transactions.
    /// Status changes only signal a current-entitlement refresh.
    func subscriptionStatusUpdates(for productIDs: Set<String>) -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task {
                for await status in Product.SubscriptionInfo.Status.updates {
                    guard !Task.isCancelled else {
                        break
                    }

                    guard case .verified(let transaction) = status.transaction,
                          productIDs.contains(transaction.productID)
                    else {
                        continue
                    }

                    continuation.yield(transaction.productID)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    private static func verified<T>(_ verification: VerificationResult<T>) throws -> T {
        switch verification {
        case .verified(let value):
            return value
        case .unverified:
            throw PurchaseFailure.verificationFailed
        }
    }

    private static func makeEntitlementRecord(_ transaction: Transaction) async -> EntitlementRecord {
        let subscriptionStatus = await transaction.subscriptionStatus
        let subscriptionState = subscriptionStatus.map {
            makeSubscriptionState($0.state)
        }

        let gracePeriodExpirationDate: Date?
        if let subscriptionStatus,
           case .verified(let renewalInfo) = subscriptionStatus.renewalInfo {
            gracePeriodExpirationDate = renewalInfo.gracePeriodExpirationDate
        } else {
            gracePeriodExpirationDate = nil
        }

        return EntitlementRecord(
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            gracePeriodExpirationDate: gracePeriodExpirationDate,
            revocationDate: transaction.revocationDate,
            isUpgraded: transaction.isUpgraded,
            productKind: makeEntitlementProductKind(transaction.productType),
            ownership: makeOwnership(transaction.ownershipType),
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            appTransactionID: transaction.appTransactionID,
            environment: makeEnvironment(transaction.environment),
            subscriptionState: subscriptionState
        )
    }

    private static func makeStoreProduct(_ product: Product) async -> StoreProduct {
        let subscription = product.subscription
        let introductoryOffer = await makeIntroductoryOffer(subscription)

        return StoreProduct(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice,
            price: NSDecimalNumber(decimal: product.price).doubleValue,
            type: makeProductType(product.type),
            subscriptionPeriod: subscription.map { subscription in
                makeSubscriptionPeriod(subscription.subscriptionPeriod)
            },
            introductoryOffer: introductoryOffer
        )
    }

    private static func makeIntroductoryOffer(
        _ subscription: Product.SubscriptionInfo?
    ) async -> StoreProduct.IntroductoryOffer? {
        guard let subscription,
              let offer = subscription.introductoryOffer
        else { return nil }

        let isEligible = await subscription.isEligibleForIntroOffer
        return StoreProduct.IntroductoryOffer(
            paymentMode: makePaymentMode(offer.paymentMode),
            period: makeSubscriptionPeriod(offer.period),
            periodCount: offer.periodCount,
            displayPrice: offer.displayPrice,
            price: NSDecimalNumber(decimal: offer.price).doubleValue,
            isEligible: isEligible
        )
    }

    private static func makeSubscriptionPeriod(
        _ period: Product.SubscriptionPeriod
    ) -> StoreProduct.SubscriptionPeriod {
        StoreProduct.SubscriptionPeriod(
            value: period.value,
            unit: makePeriodUnit(period.unit)
        )
    }

    private static func makeProductType(_ type: Product.ProductType) -> StoreProduct.ProductType {
        if type == .autoRenewable { return .autoRenewable }
        if type == .nonConsumable { return .nonConsumable }
        if type == .consumable { return .consumable }
        if type == .nonRenewable { return .nonRenewable }
        return .unknown
    }

    private static func makeEntitlementProductKind(
        _ type: Product.ProductType
    ) -> EntitlementProductKind {
        if type == .autoRenewable { return .autoRenewable }
        if type == .nonConsumable { return .nonConsumable }
        if type == .consumable || type == .nonRenewable { return .unsupported }
        return .unknown
    }

    private static func makeOwnership(
        _ ownershipType: Transaction.OwnershipType
    ) -> EntitlementOwnership {
        if ownershipType == .purchased { return .purchased }
        if ownershipType == .familyShared { return .familyShared }
        return .other
    }

    private static func makeEnvironment(
        _ environment: AppStore.Environment
    ) -> PurchaseStoreEnvironment {
        if environment == .production { return .production }
        if environment == .sandbox { return .sandbox }
        if environment == .xcode { return .xcode }
        return .unknown
    }

    private static func makeSubscriptionState(
        _ state: Product.SubscriptionInfo.RenewalState
    ) -> EntitlementSubscriptionState {
        if state == .subscribed { return .subscribed }
        if state == .inGracePeriod { return .inGracePeriod }
        if state == .inBillingRetryPeriod { return .inBillingRetryPeriod }
        if state == .expired { return .expired }
        if state == .revoked { return .revoked }
        return .unknown
    }

    private static func makePaymentMode(
        _ paymentMode: Product.SubscriptionOffer.PaymentMode
    ) -> StoreProduct.IntroductoryOffer.PaymentMode {
        if paymentMode == .freeTrial { return .freeTrial }
        if paymentMode == .payAsYouGo { return .payAsYouGo }
        if paymentMode == .payUpFront { return .payUpFront }
        return .unknown
    }

    private static func makePeriodUnit(
        _ unit: Product.SubscriptionPeriod.Unit
    ) -> StoreProduct.SubscriptionPeriod.Unit {
        switch unit {
        case .day:
            .day
        case .week:
            .week
        case .month:
            .month
        case .year:
            .year
        @unknown default:
            .unknown
        }
    }
}
