//
//  AddApplePayTransactionShortcut.swift
//  AddApplePayTransactionShortcut
//
//  Created by Andre Popovitch on 8/2/24.
//

import AppIntents


struct AddApplePayTransactionShortcut: AppIntent {
    static var title: LocalizedStringResource = "Add to Trickle"
    static var description = IntentDescription("Adds an Apple Pay transaction to Trickle")

    @Parameter(title: "Merchant Name")
    var merchantName: String

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Date")
    var date: Date

    static var parameterSummary: some ParameterSummary {
        Summary("Add $\(\.$amount) transaction from \(\.$merchantName) on \(\.$date)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let spend = Spend(name: merchantName, amount: amount, dateAdded: date)
        
        let appData = addSpend(spend: spend)
        let remaining = appData.getTrickleBalance(time: Date())

        return .result(dialog: "Added $\(String(format: "%.2f", amount)) transaction from \(merchantName), $\(String(format: "%.2f", remaining)) left")
    }
}

