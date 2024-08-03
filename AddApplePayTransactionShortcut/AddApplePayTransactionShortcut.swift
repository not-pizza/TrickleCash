//
//  AddApplePayTransactionShortcut.swift
//  AddApplePayTransactionShortcut
//
//  Created by Andre Popovitch on 8/2/24.
//

import AppIntents
import SwiftUI

struct TrickleBalanceAdjustmentView: View {
    let previousBalance: Double
    let spend: Spend
    let newBalance: Double
    let merchant: String
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(merchant)
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(-spend.amount))
                    .font(.title2)
                    .foregroundColor(.red)
                
                HStack(spacing: 2) {
                    Text(formatCurrency(previousBalance))
                        .strikethrough()
                    Image(systemName: "arrow.right")
                    Text(formatCurrency(newBalance))
                        .fontWeight(.bold)
                }
                .font(.title3)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .cornerRadius(10)
    }
}

struct AddApplePayTransactionShortcut: AppIntent {
    static var title: LocalizedStringResource = "Add to Trickle"
    static var description = IntentDescription("Adds an Apple Pay transaction to Trickle's spending log")
    
    @Parameter(title: "Card or Pass")
    var cardOrPass: String
    
    @Parameter(title: "Merchant Name")
    var merchantName: String
    
    @Parameter(title: "Name")
    var name: String

    @Parameter(title: "Amount")
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Add $\(\.$amount) transaction from \(\.$merchantName)") {
            \.$name
            \.$cardOrPass
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let spend = Spend(name: createSpendName(), amount: amount, dateAdded: Date())
        
        let time = Date();
        var appData = AppData.load();
        let previousBalance = appData.getTrickleBalance(time: time)
        appData = appData.addSpend(spend: spend).save()
        let newBalance = appData.getTrickleBalance(time: time)

        
        return .result(dialog: "Saved to Trickle 🤑") {
            TrickleBalanceAdjustmentView(previousBalance: previousBalance, spend: spend, newBalance: newBalance, merchant: merchantName)
        }
    }
    
    func createSpendName() -> String {
        var components: [String] = []
        
        if !merchantName.isEmpty {
            components.append(merchantName)
        }
        
        if !name.isEmpty {
            components.append(name)
        }
        
        if !cardOrPass.isEmpty {
            components.append("(\(cardOrPass))")
        }
        
        return components.joined(separator: " - ")
    }

}

