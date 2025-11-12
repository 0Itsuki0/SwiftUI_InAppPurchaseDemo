//
//  TransactionHistoryView.swift
//  InAppPurchaseDemo
//
//  Created by Itsuki on 2025/11/12.
//

import SwiftUI
import StoreKit

struct TransactionHistoryView: View {
    @Environment(InAppPurchaseManager.self) private var inAppPurchaseManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var transactions: [StoreKit.Transaction] = []
    @State private var showRequestRefundSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("One Time Purchase") {
                    let oneTimeTransactions = self.transactions.filter({$0.productType == .consumable || $0.productType == .nonConsumable})
                    
                    if oneTimeTransactions.isEmpty {
                        Text("No purchase made.")
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(oneTimeTransactions) { transaction in

                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Group {
                                    if let product = self.inAppPurchaseManager.productsAvailable.first(where: {$0.id == transaction.productID}) {
                                        Text(product.displayName)
                                    } else {
                                        Text(transaction.productID.components(separatedBy: ".").suffix(2).joined(separator: "."))
                                    }
                                }
                                .font(.headline)
                                
                                Group {
                                    HStack {
                                        Text("Purchased On")
                                            .fontWeight(.medium)
                                        Text(transaction.purchaseDate, format: .dateTime)
                                    }
                                    
                                    if let price = transaction.price, let currency = transaction.currency {
                                        HStack {
                                            Text("Price")
                                                .fontWeight(.medium)
                                            Text("\(price.formatted()) \(currency.identifier)")
                                        }
                                    }
                                    
                                    HStack {
                                        Text("Quantity")
                                            .fontWeight(.medium)
                                        Text("\(transaction.purchasedQuantity)")
                                    }
                                    
                                    
                                    if let revocationDate = transaction.revocationDate {
                                        HStack {
                                            Text("Purchase Cancelled On")
                                                .fontWeight(.medium)
                                            Text(revocationDate, format: .dateTime)
                                        }
                                        .foregroundStyle(.red)
                                    }
                                    
                                }
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                                
                            }
                            
                            Spacer()
                            
                            if transaction.revocationDate == nil {
                                RefundButton(transactionId: transaction.id, onRefundSuccess: {
                                    Task {
                                        self.transactions = await inAppPurchaseManager.allTransactions
                                    }
                                })
                            }

                        }
                    }
                }
                
                Section("Subscriptions") {
                    let subscriptions = self.transactions.filter({$0.productType == .autoRenewable || $0.productType == .nonRenewable})
                    
                    if subscriptions.isEmpty {
                        Text("No Subscriptions.")
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(subscriptions) { transaction in

                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Group {
                                    if let product = self.inAppPurchaseManager.productsAvailable.first(where: {$0.id == transaction.productID}) {
                                        Text(product.displayName)
                                    } else {
                                        Text(transaction.productID.components(separatedBy: ".").suffix(2).joined(separator: "."))
                                    }
                                }
                                .font(.headline)
                                
                                Group {
                                    HStack {
                                        Text("Purchased On")
                                            .fontWeight(.medium)
                                        Text(transaction.purchaseDate, format: .dateTime)
                                    }
                                    
                                    if let expirationDate = transaction.expirationDate {
                                        Text("Expired On")
                                            .fontWeight(.medium)
                                        Text(expirationDate, format: .dateTime)
                                    }
                                    
                                    if let price = transaction.price, let currency = transaction.currency {
                                        HStack {
                                            Text("Price")
                                                .fontWeight(.medium)
                                            Text("\(price.formatted()) \(currency.identifier)")
                                        }
                                    }
                                    
                                    
                                    if let revocationDate = transaction.revocationDate {
                                        HStack {
                                            Text("Subscription Cancelled On")
                                                .fontWeight(.medium)
                                            Text(revocationDate, format: .dateTime)
                                        }
                                        .foregroundStyle(.red)
                                    }
                                    
                                }
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                                
                            }
                            
                            Spacer()

                            if transaction.revocationDate == nil {
                                RefundButton(transactionId: transaction.id, onRefundSuccess: {
                                    Task {
                                        self.transactions = await inAppPurchaseManager.allTransactions
                                    }
                                })
                            }
                        }
                    }
                }

                
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .topBarTrailing, content: {
                    Button(action: {
                        self.dismiss()
                    }, label: {
                        Image(systemName: "xmark")
                    })
                })
            })
            .task {
                self.transactions = await inAppPurchaseManager.allTransactions
            }
        }
    }

}
