import SwiftUI

struct EditBucketView: View {
    @Binding var bucket: Bucket
    var save: (Bucket) -> Void
    @State private var incomePerMonth: Double
    @State private var completionDate: Date
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var nameIsFocused: Bool
    
    
    init(bucket: Binding<Bucket>, save: @escaping (Bucket) -> Void) {
        self._bucket = bucket
        self.save = save
        self._incomePerMonth = State(initialValue: bucket.wrappedValue.income * secondsPerMonth)
        self._completionDate = State(initialValue:
            Calendar.current.date(
                byAdding: .second,
                value: Int(bucket.wrappedValue.targetAmount / bucket.wrappedValue.income),
                to: Date()
            )!
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 5)
                
                TextField("Bucket Name", text: $bucket.name)
                    .focused($nameIsFocused)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Bucket size")
                        .font(.headline)
                    TextField("Target Amount", value: $bucket.targetAmount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .onChange(of: bucket.targetAmount) { _ in updateIncome() }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Monthly Contribution")
                        .font(.headline)
                    TextField("Monthly Contribution", value: $incomePerMonth, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .onChange(of: incomePerMonth) { _ in updateTargetAmount() }
                }
                
                DatePicker("Completion Date", selection: $completionDate, displayedComponents: .date)
                    .onChange(of: completionDate) { _ in updateIncomeFromDate() }

                Picker("When Finished", selection: $bucket.whenFinished) {
                    Text("Wait to Dump").tag(Bucket.FinishAction.waitToDump)
                    Text("Auto Dump").tag(Bucket.FinishAction.autoDump)
                    Text("Destroy").tag(Bucket.FinishAction.destroy)
                }
                
                Toggle("Recurring", isOn: Binding(
                    get: { bucket.recur != nil },
                    set: { if $0 { bucket.recur = 30 * 24 * 60 * 60 } else { bucket.recur = nil } }
                ))
                
                if bucket.recur != nil {
                    Stepper(value: Binding(
                        get: { Double(bucket.recur! / (24 * 60 * 60)) },
                        set: { bucket.recur = $0 * 24 * 60 * 60 }
                    ), in: 1...365) {
                        Text("Every \(Int(bucket.recur! / (24 * 60 * 60))) days")
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
            if bucket.name.isEmpty {
                nameIsFocused = true
            }
        }
    }
    
    private func updateIncome() {
        let timeInterval = completionDate.timeIntervalSince(Date())
        completionDate = Calendar.current.date(
            byAdding: .second,
            value: Int(bucket.targetAmount / bucket.income),
            to: Date()
        )!
        bucket = Bucket(
            name: bucket.name,
            targetAmount: bucket.income,
            income: bucket.income,
            whenFinished: bucket.whenFinished,
            recur: bucket.recur
        )
    }
    
    private func updateTargetAmount() {
        let timeInterval = completionDate.timeIntervalSince(Date())
        bucket = Bucket(
            name: bucket.name,
            targetAmount: (incomePerMonth / secondsPerMonth) * timeInterval,
            income: bucket.income,
            whenFinished: bucket.whenFinished,
            recur: bucket.recur
        )
    }
    
    private func updateIncomeFromDate() {
        let timeInterval = completionDate.timeIntervalSince(Date())
        bucket = Bucket(
            name: bucket.name,
            targetAmount: bucket.targetAmount,
            income: (bucket.targetAmount / timeInterval) * secondsPerMonth,
            whenFinished: bucket.whenFinished,
            recur: bucket.recur
        )
    }
    
    private func saveChanges() {
        save(bucket)
        presentationMode.wrappedValue.dismiss()
    }
}
