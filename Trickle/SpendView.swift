import Foundation
import SwiftUI

struct SpendView: View {
    @Binding var deduction: Spend
    @State private var inputAmount: String
    
    var isFocused: Bool
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case amount
        case name
    }

    init(deduction: Binding<Spend>, isFocused _isFocused: Bool) {
        self._deduction = deduction

        var amount = String(format: "%.2f", deduction.wrappedValue.amount)
        if amount.hasSuffix(".0") {
            amount = String(amount.dropLast(2))
        }
        self._inputAmount = State(initialValue: amount)
        
        isFocused = _isFocused
    }

    var nameView: some View {
        TextField("Name", text: $deduction.name)
            .focused($focusedField, equals: .name)
            .textFieldStyle(.plain)
            .background(.clear)
            .submitLabel(.done)
            .onSubmit {
                focusedField = nil
            }
    }
    
    var amountView: some View {
        TextField("Amount", text: $inputAmount)
            .focused($focusedField, equals: .amount)
            .onAppear {
                if isFocused {
                    focusedField = .amount
                }
            }
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(.plain)
            .submitLabel(.next)
            .onChange(of: inputAmount) { newValue in
                deduction.amount = toDouble(newValue) ?? 0
            }
            .background(.clear)
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                if let textField = obj.object as? UITextField {
                    textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                }
            }
            .onSubmit {
                focusedField = .name
            }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
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
                Spacer()
                nameView
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

    return SpendView(deduction: binding, isFocused: false)
}
