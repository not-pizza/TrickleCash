import SwiftUI

struct EditBucketView: View {
    @Binding var bucket: Bucket
    @State private var name: String
    @State private var targetAmount: Double
    @State private var incomePerMonth: Double
    @State private var completionDate: Date
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var nameIsFocused: Bool
    
    init(bucket: Binding<Bucket>) {
        self._bucket = bucket
        self._name = State(initialValue: bucket.wrappedValue.name)
        self._targetAmount = State(initialValue: bucket.wrappedValue.targetAmount)
        self._incomePerMonth = State(initialValue: bucket.wrappedValue.income * 60 * 60 * 24 * 30)
        self._completionDate = State(initialValue: Date() + (bucket.wrappedValue.targetAmount / bucket.wrappedValue.income))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bucket Details")) {
                    TextField("Bucket Name", text: $name)
                        .focused($nameIsFocused)
                    
                    TextField("Target Amount", value: $targetAmount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .onChange(of: targetAmount) { _ in updateIncome() }
                    
                    TextField("Monthly Income", value: $incomePerMonth, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .onChange(of: incomePerMonth) { _ in updateTargetAmount() }
                    
                    DatePicker("Completion Date", selection: $completionDate, displayedComponents: .date)
                        .onChange(of: completionDate) { _ in updateIncomeFromDate() }
                }
            }
            .navigationTitle(name.isEmpty ? "New Bucket" : name)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Save") { saveChanges() }
                    .disabled(name.isEmpty)
            )
        }
        .onAppear {
            if name.isEmpty {
                nameIsFocused = true
            }
        }
    }
    
    private func updateIncome() {
        let timeInterval = completionDate.timeIntervalSince(Date())
        incomePerMonth = (targetAmount / timeInterval) * (60 * 60 * 24 * 30)
    }
    
    private func updateTargetAmount() {
        let timeInterval = completionDate.timeIntervalSince(Date())
        targetAmount = (incomePerMonth / (60 * 60 * 24 * 30)) * timeInterval
    }
    
    private func updateIncomeFromDate() {
        let timeInterval = completionDate.timeIntervalSince(Date())
        incomePerMonth = (targetAmount / timeInterval) * (60 * 60 * 24 * 30)
    }
    
    private func saveChanges() {
        self.bucket = Bucket(
            name: name,
            targetAmount: targetAmount,
            income: self.incomePerMonth / secondsPerMonth,
            whenFinished: self.bucket.whenFinished,
            recur: self.bucket.recur
        )
        presentationMode.wrappedValue.dismiss()
    }
}
