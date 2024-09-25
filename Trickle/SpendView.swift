import Foundation
import SwiftUI

struct SpendView: View {
    @Binding var deduction: Spend
    var takeFocusWhenAppearing: Bool
    @State var inputAmount: String = ""
    @FocusState private var focusedField: Field?
    @State private var isExpanded: Bool = false
    var onDelete: () -> Void

    enum Field: Hashable {
        case amount
        case name
    }
    
    init(deduction: Binding<Spend>, isFocused: Bool, onDelete: @escaping () -> Void) {
        self._deduction = deduction
        let amount = String(format: "%.2f", deduction.wrappedValue.amount)
        self._inputAmount = State(initialValue: amount)
        self.takeFocusWhenAppearing = isFocused
        self.onDelete = onDelete
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
        TextField("45.00", text: $inputAmount)
            .inputView(
                CalculatorKeyboard.self,
                text: $inputAmount,
                onSubmit: {
                    focusedField = .name
                    inputAmount = String(format: "%.2f", deduction.amount)
                }
            )
            .focused($focusedField, equals: .amount)
            .onAppear {
                if takeFocusWhenAppearing {
                    focusedField = .amount
                }
            }
            .textFieldStyle(.plain)
            .onChange(of: inputAmount) { newValue in
                if newValue.trimmingCharacters(in: .whitespaces) == "" {
                    deduction.amount = 0
                }
                else {
                    deduction.amount = toDouble(newValue) ?? deduction.amount
                }
            }
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
                    HStack(alignment: .top, spacing: 2) {
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
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(), value: isExpanded)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isExpanded.toggle()
                        }
                    }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date Added: \(formattedDate(deduction.dateAdded))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button(action: onDelete) {
                        Text("Delete")
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

func toDouble(_ s: String) -> Double? {
    let replaced = s.replacingOccurrences(of: "×", with: "*")
                    .replacingOccurrences(of: "÷", with: "/")
    return try? Expression(replaced).evaluate()
}

#Preview {
    let spend = Spend(name: "7/11", amount: 30)
    let binding = Binding<Spend>(
        get: { spend },
        set: { _ in () }
    )
    
    SpendView(deduction: binding, isFocused: false, onDelete: {})
}
