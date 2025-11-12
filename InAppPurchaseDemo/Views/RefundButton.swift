//
//  RefundButton.swift
//  InAppPurchaseDemo
//
//  Created by Itsuki on 2025/11/12.
//

import SwiftUI
import StoreKit

struct RefundButton: View {
    var transactionId: StoreKit.Transaction.ID
    var onRefundSuccess: () -> Void
    
    @State private var showRequestRefundSheet = false
    
    var body: some View {
        Button(role: .destructive, action: {
            self.showRequestRefundSheet = true
        }, label: {
            Text("Refund")
        })
        .refundRequestSheet(for: transactionId, isPresented: $showRequestRefundSheet, onDismiss: { result in
            switch result {
            case .success(let refundStatus):
                switch refundStatus {
                case .success:
                    self.onRefundSuccess()
                case .userCancelled:
                    break
                @unknown default:
                    break
                }
                break
            case .failure(let error):
                print("refund failed with error: \(error)")
                break
            }
        })
        .buttonStyle(.borderedProminent)

    }
}
