import Foundation
import FirebaseFunctions
import StoreKit

enum PoolContributionError: LocalizedError {
    case productUnavailable
    case purchasePending
    case purchaseCancelled
    case verificationFailed
    case backendFailed(String)

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return L10n.poolPurchaseProductUnavailable
        case .purchasePending:
            return L10n.poolPurchasePending
        case .purchaseCancelled:
            return nil
        case .verificationFailed:
            return L10n.poolPurchaseVerificationFailed
        case .backendFailed(let message):
            return message
        }
    }
}

@MainActor
@Observable
final class PoolContributionStore {
    private(set) var products: [Product] = []
    private(set) var selectedTier: ShuttlePoolProduct?
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var lastError: String?

    init() {
        Task {
            await Self.finishPendingTransactions()
        }
    }

    private static func finishPendingTransactions() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            await transaction.finish()
        }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: ShuttlePoolProduct.allProductIDs)
            products = loaded.sorted { lhs, rhs in
                (ShuttlePoolProduct.matching(amount: priceAmount(for: lhs))?.rawValue ?? 0)
                    < (ShuttlePoolProduct.matching(amount: priceAmount(for: rhs))?.rawValue ?? 0)
            }
        } catch {
            lastError = error.localizedDescription
            products = []
        }
    }

    func selectTier(_ tier: ShuttlePoolProduct) {
        selectedTier = tier
        clearError()
    }

    func reportError(_ message: String) {
        lastError = message
    }

    func clearError() {
        lastError = nil
    }

    func purchaseSelectedTier(groupID: String) async throws -> PoolContributionResult {
        guard let tier = selectedTier else {
            throw PoolContributionError.productUnavailable
        }
        return try await purchase(tier: tier, groupID: groupID)
    }

    func purchase(tier: ShuttlePoolProduct, groupID: String) async throws -> PoolContributionResult {
        guard !groupID.isEmpty else {
            throw PoolContributionError.backendFailed(L10n.poolMissingGroup)
        }

        guard let product = products.first(where: { $0.id == tier.productID }) else {
            throw PoolContributionError.productUnavailable
        }

        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verify(verification)
            defer { Task { await transaction.finish() } }

            let result = try await ShuttlePoolService.recordContribution(
                groupID: groupID,
                productID: tier.productID,
                transactionID: String(transaction.id),
                contributionAmount: tier.amount
            )
            selectedTier = nil
            return result
        case .userCancelled:
            throw PoolContributionError.purchaseCancelled
        case .pending:
            throw PoolContributionError.purchasePending
        @unknown default:
            throw PoolContributionError.purchaseUnavailable
        }
    }

    /// Kutucuklarda havuz tutarı (TL); Apple ödeme sheet'i kendi fiyatını gösterir (ör. ₺29.99).
    func displayPrice(for tier: ShuttlePoolProduct) -> String {
        ShuttlePoolDisplay.formatCurrency(tier.amount)
    }

    private func priceAmount(for product: Product) -> Int {
        ShuttlePoolProduct.allCases.first { $0.productID == product.id }?.amount ?? 0
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PoolContributionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

private extension PoolContributionError {
    static var purchaseUnavailable: PoolContributionError {
        .backendFailed(L10n.poolPurchaseProductUnavailable)
    }
}

enum ShuttlePoolService {
    private static let functions = Functions.functions(region: "europe-west1")

    static func recordContribution(
        groupID: String,
        productID: String,
        transactionID: String,
        contributionAmount: Int
    ) async throws -> PoolContributionResult {
        let callable = functions.httpsCallable("recordPoolIAP")
        callable.timeoutInterval = 30

        do {
            let result = try await callable.call([
                "groupId": groupID,
                "productId": productID,
                "transactionId": transactionID,
                "contributionAmount": contributionAmount,
            ])
            guard let payload = result.data as? [String: Any],
                  payload["success"] as? Bool == true,
                  let poolCollected = Self.int(from: payload["poolCollected"]),
                  let poolTarget = Self.int(from: payload["poolTarget"]) else {
                throw PoolContributionError.backendFailed(L10n.poolPurchaseBackendFailed)
            }
            let activated = payload["activated"] as? Bool ?? false
            return PoolContributionResult(
                poolCollected: poolCollected,
                poolTarget: poolTarget,
                activated: activated
            )
        } catch let error as PoolContributionError {
            throw error
        } catch {
            throw PoolContributionError.backendFailed(Self.userFacingMessage(for: error))
        }
    }

    private static func int(from value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        let code = nsError.userInfo["code"] as? String ?? nsError.localizedDescription

        switch code {
        case "group_not_found":
            return L10n.poolMissingGroup
        case "not_group_member":
            return L10n.poolNotGroupMember
        case "invalid_pool_payment_payload":
            return L10n.poolPurchaseBackendFailed
        case "auth_required":
            return L10n.signInRequired
        case "NOT FOUND", "not-found":
            return L10n.poolFunctionNotDeployed
        default:
            if nsError.localizedDescription.uppercased() == "NOT FOUND" {
                return L10n.poolFunctionNotDeployed
            }
            return nsError.localizedDescription
        }
    }
}
