import SwiftUI

struct EditBucketView: View {
    @Binding var bucket: Bucket
    var save: (Bucket) -> Void
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var nameIsFocused: Bool
    
    @State private var monthlyContribution: Double
    @State private var completionDate: Date
    
    @State private var targetAmountInput: String
    
    init(bucket: Binding<Bucket>, save: @escaping (Bucket) -> Void) {
        self._bucket = bucket
        self.save = save
        
        let initialBucket = bucket.wrappedValue
        self._monthlyContribution = State(initialValue: initialBucket.income * secondsPerMonth)
        self._completionDate = State(initialValue: initialBucket.estimatedCompletionDate)
        self._targetAmountInput = State(initialValue: String(format: "%.2f", initialBucket.targetAmount))
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 5)
                
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Bucket Name", text: $bucket.name)
                        .focused($nameIsFocused)
                        .font(.title)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Bucket size")
                        .font(.headline)
                    TextField("Target Amount", text: $targetAmountInput)
                        .inputView(
                            CalculatorKeyboard.self,
                            text: $targetAmountInput,
                            onSubmit: {
                                targetAmountInput = String(format: "%.2f", bucket.targetAmount)
                            }
                        )
                        .onChange(of: targetAmountInput) { _ in updateCalculations() }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Monthly Contribution")
                        .font(.headline)
                    TextField("Monthly Contribution", value: $monthlyContribution, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .onChange(of: monthlyContribution) { _ in updateCalculations() }
                }
                
                DatePicker("Completion Date", selection: $completionDate, displayedComponents: .date)
                    .onChange(of: completionDate) { _ in updateCalculations() }

                Picker("When Finished", selection: $bucket.whenFinished) {
                    Text("Wait to Dump").tag(Bucket.FinishAction.waitToDump)
                    Text("Auto Dump").tag(Bucket.FinishAction.autoDump)
                    Text("Destroy").tag(Bucket.FinishAction.destroy)
                }
                
                Toggle("Recurring", isOn: Binding(
                    get: { bucket.recur != nil },
                    set: { bucket.recur = $0 ? 30 * 24 * 60 * 60 : nil }
                ))
                
                if let recur = bucket.recur {
                    Stepper(value: Binding(
                        get: { Double(recur / (24 * 60 * 60)) },
                        set: { bucket.recur = $0 * 24 * 60 * 60 }
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
                    .disabled(bucket.name.isEmpty)
            )
        }
        .onAppear {
            nameIsFocused = bucket.name.isEmpty
        }
    }
    
    private func updateCalculations() {
        let secondsUntilCompletion = completionDate.timeIntervalSince(Date())
        bucket.income = bucket.targetAmount / secondsUntilCompletion
        monthlyContribution = bucket.income * secondsPerMonth
    }
    
    private func saveChanges() {
        save(bucket)
        presentationMode.wrappedValue.dismiss()
    }
}

extension Bucket {
    var estimatedCompletionDate: Date {
        Calendar.current.date(
            byAdding: .second,
            value: Int(targetAmount / income),
            to: Date()
        ) ?? Date()
    }
}
