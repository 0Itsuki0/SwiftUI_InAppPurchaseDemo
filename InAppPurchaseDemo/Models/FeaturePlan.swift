//
//  FeaturePlan.swift
//  InAppPurchaseDemo
//
//  Created by Itsuki on 2025/11/12.
//

import StoreKit

enum FeaturePlan: String {
    case free
    case plus
    case premium
    
    init(productId: Product.ID) {
        guard let planString = productId.components(separatedBy: ".").last else {
            self = .free
            return
        }
        self = .init(rawValue: planString) ?? .free
    }
}
