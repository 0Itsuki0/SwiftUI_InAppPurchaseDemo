//
//  ContentView.swift
//  InAppPurchaseDemo
//
//  Created by Itsuki on 2025/11/09.
//

import SwiftUI
import StoreKit


struct ContentView: View {
    @State private var inAppPurchaseManager = InAppPurchaseManager()
    @State private var purchasingProductId: Product.ID?
    @State private var showAllTransactions: Bool = false
    @State private var showSubscriptionSheet: Bool = false
    @State private var showManageSubscriptionSheet = false

    var body: some View {
        NavigationStack {
            List {
                
                Section {
                    HStack {
                        Text("Current Plan")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(self.inAppPurchaseManager.subscribedAdvanceFeature.rawValue)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Gacha Stone")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(self.inAppPurchaseManager.gachaStone)")
                            .foregroundStyle(.secondary)
                    }
                    
                    
                    HStack {
                        Text("Remove Ads")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(self.inAppPurchaseManager.ownedNonConsumables.contains(ProductsConfiguration.removeAdsIdentifier)))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            try await AppStore.sync()
                        }
                    }, label: {
                        Text("Restore Purchases")
                    })
                    
                    Button(action: {
                        showAllTransactions = true
                    }, label: {
                        Text("All Transactions")
                    })
                    
                    Button(action: {
                        showManageSubscriptionSheet = true
                    }, label: {
                        Text("Manage Subscription")
                    })
                    .manageSubscriptionsSheet(isPresented: $showManageSubscriptionSheet, subscriptionGroupID: ProductsConfiguration.featuresSubscriptionGroupId)
                    
                }
                
                Section("Subscriptions") {
                    Button(action: {
                        showSubscriptionSheet = true
                    }, label: {
                        Text("Plans")
                    })
                    .sheet(isPresented: $showSubscriptionSheet, content: {
                        SubscriptionStoreView(subscriptions: inAppPurchaseManager.featuresSubscriptionProducts)
                        .storeButton(.visible, for: .restorePurchases)
                    })
                }
                

                
                Section("Gacha Stones") {
                    ForEach(inAppPurchaseManager.gachaProducts) { product in
                        
                        ProductView(product, prefersPromotionalIcon: false, icon: {
                            Image(systemName: "bubbles.and.sparkles")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.yellow)
                                .frame(width: 48)
                                .padding(.all, 8)
                        })
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .productViewStyle(.compact)
                    }
                }
                
                Section("Other Products") {
                    ForEach(inAppPurchaseManager.nonConsumableProducts) { product in
                        
                        ProductView(product, prefersPromotionalIcon: false, icon: {
                            Image(systemName: "heart.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.red)
                                .frame(width: 48)
                                .padding(.all, 8)
                        })
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .productViewStyle(.compact)
                    }

                }
               
            }
            .contentMargins(.top, 8)
            .disabled(self.purchasingProductId != nil)
            .navigationTitle("In App Purchase")
            .navigationBarTitleDisplayMode(.large)
            .onInAppPurchaseStart { product in
                self.purchasingProductId = product.id
            }
            .onInAppPurchaseCompletion { product, result in
                Task {
                    defer {
                        self.purchasingProductId = nil
                    }
                    await  self.inAppPurchaseManager.processPurchaseCompletionResult(result)
                }
            }
            .sheet(isPresented: $showAllTransactions, content: {
                TransactionHistoryView()
                    .environment(self.inAppPurchaseManager)
            })

        }
    }
}


//#Preview {
//    ContentView()
//}
