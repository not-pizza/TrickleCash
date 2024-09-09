import SwiftUI

struct EditBucketView: View {
    var save: (Bucket) -> Void
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var nameIsFocused: Bool
    
    private var amount: Double
    @State private var completionDate: Date
    @State private var targetAmountInput: String
    @State private var monthlyContributionInput: String
    @State private var nameInput: String
    @State private var whenFinished: Bucket.FinishAction
    @State private var recur: TimeInterval?
    
    init(bucket: Bucket, amount: Double, save: @escaping (Bucket) -> Void) {
        self.save = save
        
        self._completionDate = State(initialValue: bucket.estimatedCompletionDate(amount, at: Date()) ?? Date.distantFuture)
        self._targetAmountInput = State(initialValue: String(format: "%.2f", bucket.targetAmount))
        self._monthlyContributionInput = State(initialValue: String(format: "%.2f", bucket.income * secondsPerMonth))
        self._nameInput = State(initialValue: bucket.name)
        self._whenFinished = State(initialValue: bucket.whenFinished)
        self._recur = State(initialValue: bucket.recur)
        self.amount = amount
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 5)
                
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Bucket Name", text: $nameInput)
                        .focused($nameIsFocused)
                        .font(.title)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Fill up to:")
                        .font(.headline)
                    
                    HStack(alignment: .top, spacing: 2) {
                        Text("$")
                        TextField("Target Amount", text: targetAmountBinding)
                            .keyboardType(.decimalPad)
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Monthly Contribution:")
                        .font(.headline)
                    
                    HStack(alignment: .top, spacing: 2) {
                        Text("$")
                        TextField("Monthly Contribution", text: monthlyContributionBinding)
                            .keyboardType(.decimalPad)
                    }
                }
                
                DatePicker(
                    "Completion Date:",
                    selection: completionDateBinding,
                    in: Calendar.current.date(byAdding: .day, value: 1, to: Date())!.startOfDay...,
                    displayedComponents: .date
                )
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("When Filled:")
                        .font(.headline)
                    
                    Picker("When Filled", selection: $whenFinished) {
                        Text("Do nothing").tag(Bucket.FinishAction.waitToDump)
                        Text("Automatically dump into main balance").tag(Bucket.FinishAction.autoDump)
                        Text("Destroy (as if you spent the money)").tag(Bucket.FinishAction.destroy)
                    }
                }
                
                Toggle("Recurring", isOn: Binding(
                    get: { recur != nil },
                    set: { recur = $0 ? 30 * 24 * 60 * 60 : nil }
                ))
                
                if let recur = recur {
                    Stepper(value: Binding(
                        get: { Double(recur / (24 * 60 * 60)) },
                        set: { self.recur = $0 * 24 * 60 * 60 }
                    ), in: 1...365) {
                        Text("Every \(Int(recur / (24 * 60 * 60))) days")
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Save") { saveChanges() }
                    .disabled(nameInput.isEmpty)
            )
        }
        .onAppear {
            nameIsFocused = nameInput.isEmpty
        }
    }
    
    private var targetAmountBinding: Binding<String> {
        Binding(
            get: { targetAmountInput },
            set: { newValue in
                targetAmountInput = newValue
                updateCompletionDate()
            }
        )
    }
    
    private var monthlyContributionBinding: Binding<String> {
        Binding(
            get: { monthlyContributionInput },
            set: { newValue in
                monthlyContributionInput = newValue
                updateCompletionDate()
            }
        )
    }
    
    private var completionDateBinding: Binding<Date> {
        Binding(
            get: { completionDate },
            set: { newValue in
                completionDate = newValue
                updateMonthlyContribution()
            }
        )
    }
    
    private func updateCompletionDate() {
        if let (monthlyContribution, targetAmount) = cleanData(monthlyContributionInput: monthlyContributionInput, targetAmountInput: targetAmountInput) {
            if targetAmount > amount {
                let income = monthlyContribution / secondsPerMonth
                if income > 0.01 / secondsPerMonth {
                    completionDate = Calendar.current.date(byAdding: .second, value: Int((targetAmount - amount) / income), to: Date()) ?? Date.distantFuture
                }
            }
        }
    }
    
    private func updateMonthlyContribution() {
        if let targetAmount = toDouble(targetAmountInput) {
            let income = targetAmount / (completionDate.timeIntervalSince(Date()))
            monthlyContributionInput = String(format: "%.2f", income * secondsPerMonth)
        }
    }
    
    private func cleanData(monthlyContributionInput: String, targetAmountInput: String) -> (monthlyContribution: Double, targetAmount: Double)? {
        if let monthlyContributionInput = toDouble(monthlyContributionInput),
           monthlyContributionInput != 0,
           let targetAmountInput = toDouble(targetAmountInput),
           targetAmountInput != 0 {
            return (monthlyContribution: monthlyContributionInput, targetAmount: targetAmountInput)
        }
        return nil
    }
    
    private func derivedBucket() -> Bucket? {
        if let (monthlyContribution, targetAmount) = cleanData(monthlyContributionInput: monthlyContributionInput, targetAmountInput: targetAmountInput) {
            return Bucket(name: nameInput, targetAmount: targetAmount, income: monthlyContribution / secondsPerMonth, whenFinished: self.whenFinished, recur: recur)
        }
        return nil
    }
    
    private func saveChanges() {
        if let bucket = self.derivedBucket() {
            save(bucket)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

extension Bucket {
    func estimatedCompletionDate(_ amount: Double, at: Date) -> Date {
        if income <= 0.01 / secondsPerMonth {
            return Date.distantFuture
        }
        return Calendar.current.date(
            byAdding: .second,
            value: Int((targetAmount - amount) / income),
            to: at
        ) ?? Date.distantFuture
    }
}
