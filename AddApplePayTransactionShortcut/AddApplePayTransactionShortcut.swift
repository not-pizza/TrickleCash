//
//  AddApplePayTransactionShortcut.swift
//  AddApplePayTransactionShortcut
//
//  Created by Andre Popovitch on 8/2/24.
//

import AppIntents
import SwiftUI
import Oklab

struct TrickleBalanceAdjustmentView: View {
    let previousBalance: Double
    let spend: Spend
    let newBalance: Double
    let merchant: String
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        var spendColor = OklabColor(swiftUI: Color.red)
        spendColor.lightness += colorScheme == .dark ? 0.1 : -0.1
        return ZStack {
            balanceBackgroundGradient(newBalance, colorScheme: colorScheme, boost: 0.2)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(merchant)
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    Text("Balance")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(-spend.amount))
                        .font(.title2)
                        .foregroundColor(Color(spendColor))
                    
                    HStack(spacing: 2) {
                        Text(formatCurrencyNoDecimals(previousBalance))
                            .strikethrough()
                            .bold()
                        Image(systemName: "arrow.right")
                        Text(formatCurrencyNoDecimals(newBalance))
                            .fontWeight(.bold)
                    }
                    .font(.title3)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .cornerRadius(10)
        }
        .cornerRadius(10)
    }
}

struct AddApplePayTransactionShortcut: AppIntent {
    static var title: LocalizedStringResource = "Add to Trickle"
    static var description = IntentDescription("Adds an Apple Pay transaction to Trickle's spending log")
    
    @Parameter(title: "Card or Pass")
    var cardOrPass: String?
    
    @Parameter(title: "Merchant Name")
    var merchantName: String
    
    @Parameter(title: "Name")
    var name: String?

    @Parameter(title: "Amount")
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Add a $\(\.$amount) transaction from \(\.$merchantName)") {
            \.$name
            \.$cardOrPass
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        var transactionName = merchantName
        if let name = name {
            if name.trimmingCharacters(in: .whitespaces) != "" {
                transactionName = name
            }
        }
        
        let spend = Spend(name: transactionName, merchant: merchantName, paymentMethod: cardOrPass, amount: amount, dateAdded: Date(), addedFrom: .shortcut)
        
        let time = Date();
        var appData = AppData.loadOrDefault();
        let previousBalance = appData.getAppState(asOf: time).balance
        appData = appData.addSpend(spend).save()
        let newBalance = appData.getAppState(asOf: time).balance

        
        return .result(dialog: "Saved to Trickle 🤑") {
            TrickleBalanceAdjustmentView(previousBalance: previousBalance, spend: spend, newBalance: newBalance, merchant: merchantName)
        }
    }
}
