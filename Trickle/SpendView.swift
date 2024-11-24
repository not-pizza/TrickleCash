import Foundation
import SwiftUI

struct SpendView: View {
    @Binding var deduction: Spend
    var buckets: [MinimalBucketInfo]
    var takeFocusWhenAppearing: Bool
    var startDate: Date
    @State var inputAmount: String = ""
    @FocusState private var focusedField: Field?
    var onDelete: () -> Void
    var bucketValidAtDate: (UUID, Date) -> Bool
    
    enum Field: Hashable {
        case amount
        case name
    }
    
    init(deduction: Binding<Spend>, buckets: [MinimalBucketInfo], isFocused: Bool, startDate: Date, onDelete: @escaping () -> Void, bucketValidAtDate: @escaping (UUID, Date) -> Bool) {
        self._deduction = deduction
        self.buckets = buckets
        let amount = String(format: "%.2f", -deduction.wrappedValue.amount)
        self._inputAmount = State(initialValue: amount)
        self.takeFocusWhenAppearing = isFocused
        self.onDelete = onDelete
        self.startDate = startDate
        self.bucketValidAtDate = bucketValidAtDate
    }
    
    var nameView: some View {
        HStack {
            TextField("Name", text: $deduction.name)
                .focused($focusedField, equals: .name)
                .textFieldStyle(.plain)
                .background(.clear)
                .submitLabel(.done)
                .onSubmit {
                    withAnimation {
                        focusedField = nil
                    }
                }
                .controlSize(.large)
        }
    }
    
    var amountInput: some View {
        TextField("45.00", text: $inputAmount)
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: .amount)
            .onAppear {
                if takeFocusWhenAppearing {
                    withAnimation {
                        focusedField = .amount
                    }
                }
            }
            .textFieldStyle(.plain)
            .onChange(of: inputAmount) { newValue in
                if newValue.trimmingCharacters(in: .whitespaces) == "" {
                    deduction.amount = 0
                }
                else {
                    deduction.amount = -(toDouble(newValue) ?? -deduction.amount)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                if let textField = obj.object as? UITextField {
                    // We don't want to select the leading `-`if one is present
                    if let text = textField.text {
                        if text.hasPrefix("-") {
                            if let startPosition = textField.position(from: textField.beginningOfDocument, offset: 1) {
                                // Create text range from position to end
                                if let newRange = textField.textRange(from: startPosition, to: textField.endOfDocument) {
                                    // Set the selection
                                    textField.selectedTextRange = newRange
                                }
                            }
                        }
                        else {
                            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }
                    else {
                        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                    }
                }
            }
            .onSubmit {
                withAnimation {
                    focusedField = .name
                }
            }
            .controlSize(.large)

    }
    
    var amountView: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 2) {
                Text("$")
                if #available(iOS 16.0, *) {
                    amountInput
                        .bold()
                } else {
                    amountInput
                }
            }
            if let paymentMethod = deduction.paymentMethod {
                Text(paymentMethod)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    var dateBinding: Binding<Date> {
        .init(
            get: { deduction.dateAdded },
            set: {
                deduction.dateAdded = $0
                if let fromBucket = deduction.fromBucket {
                    if !bucketValidAtDate(fromBucket, $0) {
                        deduction.fromBucket = nil
                    }
                }
            }
        )
    }
    
    var sortedBuckets: [MinimalBucketInfo] {
        buckets.sorted { $0.name < $1.name }
    }
    
    var expandedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack{
                    DatePicker(
                        "Date Added",
                        selection: dateBinding,
                        in: startDate...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(CompactDatePickerStyle())
                    .labelsHidden()
                }
                
                if !buckets.isEmpty {
                    Spacer()
                    HStack {
                        Picker("From", selection: $deduction.fromBucket) {
                            Text("Main Balance")
                                .tag(nil as UUID?)
                            
                            ForEach(sortedBuckets) { bucket in
                                Text(bucket.name)
                                    .tag(bucket.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)
                    }
                    Spacer()
                }
            }

            Toggle(isOn: Binding(
                get: { deduction.amount < 0 },
                set: { inputAmount = $0 ?
                    String(format: "%.2f", abs(toDouble(inputAmount) ?? deduction.amount)) :
                    String(format: "%.2f", -abs((toDouble(inputAmount) ?? deduction.amount)))
                }
            )) {
                Text("Windfall")
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    var body: some View {
        // TODO: switch to grid once we remove support for iOS 15
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    amountView
                    Spacer()
                    nameView
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        if focusedField == .amount {
                            Button("Delete") {
                                withAnimation {
                                    focusedField = nil
                                    onDelete()
                                }
                            }
                            .buttonStyle(.plain)
                            .padding()
                            
                            Spacer()
                            
                            Button("+") {
                                inputAmount += "+"
                            }
                            .buttonStyle(.plain)
                            .padding(3)
                            
                            Button("-") {
                                inputAmount += "-"
                            }
                            .buttonStyle(.plain)
                            .padding(3)
                            
                            Button("×") {
                                inputAmount += "×"
                            }
                            .buttonStyle(.plain)
                            .padding(3)
                            
                            Button("÷") {
                                inputAmount += "÷"
                            }
                            .buttonStyle(.plain)
                            .padding(3)
                            
                            Spacer()
                            
                            Button("Name →") {
                                focusedField = .name
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.leading)
                        }
                        else if focusedField == .name {
                            Button("Delete") {
                                withAnimation {
                                    focusedField = nil
                                    onDelete()
                                }
                            }
                            .buttonStyle(.plain)
                            .padding()
                            
                            Spacer()
                            
                            Button("Done") {
                                focusedField = nil
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.leading)
                        }
                        else{
                            EmptyView()
                        }
                    }
                }
                
                if focusedField != nil {
                    expandedView
                }
            }
            .onChange(of: focusedField) { newValue in
                if let input = toDouble(inputAmount) {
                    inputAmount = String(format: "%.2f", input)
                }
            }
            .animation(.default, value: focusedField)
            .padding(focusedField != nil ? 12 : 5)
            .background(focusedField != nil ? Color(.systemGray6) : Color.clear)
            .cornerRadius(focusedField != nil ? 12 : 0)
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
    
    SpendView(deduction: binding, buckets: [], isFocused: false, startDate: Date(), onDelete: {}, bucketValidAtDate: {_, _ in true})
}
