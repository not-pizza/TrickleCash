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

    var nameView: some View {
        TextField("Name", text: $deduction.name)
            .textFieldStyle(.plain)
            .background(.clear)
    }
    
    var amountView: some View {
        TextField("Amount", text: $inputAmount)
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(.plain)
            .onChange(of: inputAmount) { newValue in
                deduction.amount = toDouble(newValue) ?? 0
            }
            .background(.clear)
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                if let textField = obj.object as? UITextField {
                    textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                }
            }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                nameView
                Spacer()
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        Text("$")
                        if #available(iOS 16.0, *) {
                            amountView
                                .bold()
                        } else {
                            amountView
                        }
                    }
                    if let paymentMethod = deduction.paymentMethod {
                        Text(paymentMethod)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}


func toDouble(_ s: String) -> Double? {
    return try? Expression(s).evaluate()
}

#Preview {
    let spend = Spend(name: "7/11", amount: 30)
    let binding = Binding<Spend>(
        get: { spend },
        set: { _ in () }
    )

    return SpendView(deduction: binding)
}
