//
//  SpendView.swift
//  Trickle
//
//  Created by Andre Popovitch on 8/3/24.
//

import Foundation
import SwiftUI

struct SpendView: View {
    @Binding var deduction: Spend
    @State private var inputAmount: String

    init(deduction: Binding<Spend>) {
        self._deduction = deduction

        var amount = String(format: "%.2f", deduction.wrappedValue.amount)
        if amount.hasSuffix(".0") {
            amount = String(amount.dropLast(2))
        }
        self._inputAmount = State(initialValue: amount)
    }

    var body: some View {
        HStack {
            TextField("Name", text: $deduction.name)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            Spacer()
            TextField("Amount", text: $inputAmount)
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .onChange(of: inputAmount) { newValue in
                if let value = Double(newValue) {
                    deduction.amount = value
                } else if inputAmount.isEmpty {
                    deduction.amount = 0
                }
            }
        }
    }
}
