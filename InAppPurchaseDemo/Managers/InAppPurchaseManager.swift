//
//  InAppPurchaseManager.swift
//  InAppPurchaseDemo
//
//  Created by Itsuki on 2025/11/11.
//


import StoreKit

@Observable
class InAppPurchaseManager {
    enum _Error: Error {
        case failToVerifyTransaction(StoreKit.Transaction, VerificationResult<StoreKit.Transaction>.VerificationError)
        case failToPurchase(Error)
    }
    
    private(set) var error: Error? {
        didSet {
            if let error {
                print(error)
            }
        }
    }
    
    private(set) var productsAvailable: [Product] = []
    
    var gachaProducts: [Product] {
        return self.productsAvailable.filter({$0.id.contains(ProductsConfiguration.gachaStoneIdentifier)}).sorted(by: { first, second in
            return (self.parseProductIdForStones(first.id) ?? 0) < (self.parseProductIdForStones(second.id) ?? 0)
        })
    }
    
    var nonConsumableProducts: [Product] {
        return self.productsAvailable.filter({$0.type == .nonConsumable}).sorted(by: {first, second in first.displayName < second.displayName})
    }
    
    var featuresSubscriptionProducts: [Product] {
        return self.productsAvailable.filter({$0.type == .autoRenewable && $0.subscription?.subscriptionGroupID == ProductsConfiguration.featuresSubscriptionGroupId}).sorted(by: { first, second in
            (first.subscription?.groupLevel ?? 1) < (second.subscription?.groupLevel ?? 1)
        })
    }
    
    var allTransactions: [Transaction] {
        get async {
            var transactions: [Transaction] = []
            // By default, when the SKIncludeConsumableInAppPurchaseHistory property list key is false, the transaction information excludes finished consumables (unless refunded or revoked).
            for await verificationResult in Transaction.all {
                if case .verified(let transaction) = verificationResult {
                    transactions.append(transaction)
                }
            }
            return transactions
        }
    }
    
    // consumable purchase
    private static let gachaStoneKey = "gachaStone"
    // NOTE:
    // For simplification, UserDefaults is used here.
    // To share between multiple devices, please consider using SwiftData + iCloud instead.
    private(set) var gachaStone: Int = 0 {
        didSet {
            UserDefaults.standard.setValue(self.gachaStone, forKey: InAppPurchaseManager.gachaStoneKey)
        }
    }
    
    // nonConsumable Purchase
    private(set) var ownedNonConsumables: Set<Product.ID> = []

    // auto-renew subscription
    private var subscriptionStatuses: [SubscriptionGroupID: [SubscriptionStatus]] = [:]
    var subscribedAdvanceFeature: FeaturePlan {
        guard let statuses = subscriptionStatuses.filter({$0.key == ProductsConfiguration.featuresSubscriptionGroupId}).first?.value else {
            return .free
        }
        // user should still be able to continue using the subscription even when it is revoked, but before expiration
        let subscribed = statuses.filter({$0.state != .expired}).map(\.transaction.unsafePayloadValue.productID)
        let products = self.featuresSubscriptionProducts.filter({product in subscribed.contains(product.id)}).sorted(by: { first, second in
            (first.subscription?.groupLevel ?? 1) < (second.subscription?.groupLevel ?? 1)
        })
        guard let productId = products.first?.id else {
            return .free
        }
        return FeaturePlan(productId: productId)
    }
    

    // Task for transactions updates
    @ObservationIgnored
    private var transactionUpdatesTask: Task<Void, any Error>?
    
    // Task for subscriptions updates
    @ObservationIgnored
    private var statusUpdatesTask: Task<Void, any Error>?

    init() {
        self.gachaStone = UserDefaults.standard.integer(forKey: InAppPurchaseManager.gachaStoneKey)

        self.observeTransactionUpdates()
        self.observeSubscriptionStatusUpdates()
        
        Task {
            await self.loadCurrentSubscriptionStatuses()
            await self.loadCurrentEntitlements()
            await self.loadProducts()
        }
    }

    deinit {
        self.statusUpdatesTask?.cancel()
        self.transactionUpdatesTask?.cancel()
    }
    
    private func loadProducts() async {
        do {
            // Request products from the App Store (or local configuration file)
            self.productsAvailable = try await Product.products(for: ProductsConfiguration.productIds)
        } catch(let error) {
            self.error = error
        }
    }

}


// MARK: One Time Transaction
extension InAppPurchaseManager {
    
    func processPurchaseCompletionResult(_ purchaseResult: Result<Product.PurchaseResult, any Error>) async {
        let result: Product.PurchaseResult
        switch purchaseResult {
        case .success(let r):
            result = r
            break
        case .failure(let error):
            self.error = _Error.failToPurchase(error)
            return
        }
        
        switch result {
        case .success(let verificationResult):
            await self.processVerificationResult(verificationResult)
            break
        case .pending:
            print("pending purchase...")
            // These purchases may succeed in the future,
            // and the resulting `Transaction` will be delivered via `Transaction.updates`
            break
            
        case .userCancelled:
            print("user cancelled...")
            break
            
        @unknown default:
            break
        }
    }
    
    private func processVerificationResult(_ verificationResult: VerificationResult<Transaction>) async {
        switch verificationResult {
        case .unverified(let transaction, let verificationResult):
            self.error = _Error.failToVerifyTransaction(transaction, verificationResult)
            break
        case .verified(let transaction):
            await self.processTransaction(transaction)
        }
    }
    
    
    private func processTransaction(_ transaction: Transaction) async {
        // Only handle consumables and non consumables here.
        // subscription features are handled based on the subscription status.
        switch transaction.productType {
        case .autoRenewable:
            await transaction.finish()
            break
        case .consumable:
            await self.processConsumableTransaction(transaction)
            break
        case .nonConsumable:
            await self.processNonConsumableTransaction(transaction)
            break
        case .nonRenewable:
            await transaction.finish()
            break
        default:
            await transaction.finish()
        }
    }

    
    private func processConsumableTransaction(_ transaction: Transaction) async {
        guard transaction.productType == .consumable else {
            return
        }
        
        let quantity: Int? = if transaction.productID.contains(ProductsConfiguration.gachaStoneIdentifier), let quantity = self.parseProductIdForStones(transaction.productID) { quantity } else { nil }
        
        guard let quantity else {
            print("failed to get gacha stone quantity.")
            return
        }
        
        if transaction.revocationDate == nil, transaction.revocationReason == nil {
            self.gachaStone = min(self.gachaStone + quantity, Int.max)
        } else {
            self.gachaStone = max(self.gachaStone - quantity, Int.min)
        }

        // Finish the transaction after granting the user content.
        await transaction.finish()
    }

    private func processNonConsumableTransaction(_ transaction: Transaction) async {
        guard transaction.productType == .nonConsumable else {
            return
        }

        if transaction.revocationDate == nil, transaction.revocationReason == nil {
            self.ownedNonConsumables.insert(transaction.productID)
        } else {
            self.ownedNonConsumables.remove(transaction.productID)
        }

        // Finish the transaction after granting the user content.
        await transaction.finish()
    }
    
    private func parseProductIdForStones(_ productId: Product.ID) -> Int? {
        guard let quantityString = productId.components(separatedBy: ".").last,
              let quantity = Int(quantityString) else {
            return nil
        }
        return quantity
    }
    
    
    // Observe transaction updates to handle
    // - pending transactions
    // - refunds
    // - transactions that occur outside of the app, such as Ask to Buy transactions, subscription offer code redemptions, and purchases that customers make in the App Store.
    // - transactions that customers complete in the app on another device.
    //
    // Successful/cancelled ones will be delivered to onInAppPurchaseCompletion(perform:).
    // To have those transactions to be emitted from Transaction.updates as well, providing a nil for the action to perform on the modifier.
    //
    // Also, we are not handling subscriptions here but use SubscriptionStatus.updates instead.
    private func observeTransactionUpdates() {
        self.transactionUpdatesTask = Task(priority: .background) { [weak self] in
            for await verificationResult in Transaction.updates {
                print("transaction update: \(verificationResult.unsafePayloadValue.productID)")
                guard let self else { return }
                await self.processVerificationResult(verificationResult)
            }
        }
    }
    
    
    // Load the current Entitlements
    // Consumable In-App Purchases don’t appear in the current entitlements.
    //
    // We are not handling subscriptions here but use SubscriptionStatus.all instead.
    private func loadCurrentEntitlements() async {
        // there is  also the currentEntitlementTask(for:priority:action:) modifier we can use directly with a view
        for await verificationResult in Transaction.currentEntitlements {
            print("currentEntitlements: \(verificationResult.unsafePayloadValue.productID)")
            Task.detached(priority: .background) {
                await self.processVerificationResult(verificationResult)
            }
        }
    }
    
    // Load any unfinished transactions to process
    private func checkForUnfinishedTransactions() async {
        for await verificationResult in Transaction.unfinished {
            print("unfinished transaction: \(verificationResult.unsafePayloadValue.productID)")
            Task.detached(priority: .background) {
                await self.processVerificationResult(verificationResult)
            }
        }
    }
}



// MARK: Subscriptions
extension InAppPurchaseManager {
    
    // Observe subscription status update
    //
    // Here is also where we will be handling
    // - new subscriptions
    // - refunds
    // - expirations
    // Those can happen either because user perform some actions on this device, on other devices, or due to family share.
    private func observeSubscriptionStatusUpdates() {
        statusUpdatesTask = Task(priority: .background) { [weak self] in
            // there is also the subscriptionStatusTask(for:priority:action:) modifier we can use
            for await status in SubscriptionStatus.updates {
                print("subscription status update: \(status.transaction.unsafePayloadValue.productID)")
                guard let self else { return }

                let transaction: Transaction
                switch status.transaction {
                case .unverified(let transaction, let verificationResult):
                    self.error = _Error.failToVerifyTransaction(transaction, verificationResult)
                    continue
                case .verified(let t):
                    transaction = t
                }
                
                guard let subscriptionGroupID = transaction.subscriptionGroupID else {
                    continue
                }

                let currentStatuses = self.subscriptionStatuses[subscriptionGroupID]

                if let currentStatuses {
                    self.subscriptionStatuses[subscriptionGroupID]  = currentStatuses.filter({$0.transaction.unsafePayloadValue.ownershipType == transaction.ownershipType}) + [status]
                } else {
                    self.subscriptionStatuses[subscriptionGroupID] = [status]
                }
            }
        }
    }
    
    // Get current subscription status
    private func loadCurrentSubscriptionStatuses() async {
        // There is also the subscriptionStatusTask(for:priority:action:) modifier we can use to get the status of a specific subscription group.
        for await (subscriptionGroupID, statuses) in SubscriptionStatus.all {
            print("subscription status: \(subscriptionGroupID)")
            print("\(statuses.map(\.state.localizedDescription))")
            self.subscriptionStatuses[subscriptionGroupID] = statuses
        }
    }
}
