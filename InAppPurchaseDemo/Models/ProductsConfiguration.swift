//
//  ProductsConfiguration.swift
//  InAppPurchaseDemo
//
//  Created by Itsuki on 2025/11/12.
//

import StoreKit

// hard coding ids here but we can also decode the store kit configuration file which is just some JSON.
// However, do keep in mind that synced configuration file (non-local testing ones, but those linked with App store connect) is only available for Xcode 14 or later.
final class ProductsConfiguration {
    static let policyText: String = "Some Policy"
    static let policyURL: String = ""
    
    static let gachaStoneIdentifier: String = "gachaStone"
    static let removeAdsIdentifier: String = "nonconsumable.removeAds"
    static let featuresSubscriptionGroupId: SubscriptionGroupID = "C4E9A6CF"
    
    static let consumableProducts: [Product.ID] = ["consumable.gachaStone.100", "nonconsumable.removeAds", "consumable.gachaStone.500", "consumable.gachaStone.1000", "consumable.gachaStone.10000"]
    
    static let nonConsumableProducts: [Product.ID] = [removeAdsIdentifier]

    static let subscriptionGroups: [SubscriptionGroupID : [Product.ID]] = [
        featuresSubscriptionGroupId: ["subscription.autoRenew.features.plus", "subscription.autoRenew.features.premium"]
    ]

    static var productIds: [Product.ID] = consumableProducts + nonConsumableProducts + subscriptionGroups.flatMap(\.value)
}
