import SwiftUI

struct Spend: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var dateAdded: Date = Date()
}

struct SpendView: View {
    @Binding var deduction: Spend
    @State private var inputAmount: String
    var onSave: () -> Void  // Closure to trigger save in the parent view

    init(deduction: Binding<Spend>, onSave: @escaping () -> Void) {
        self._deduction = deduction

        // if the input amount ends with .0, remove it
        var amount = String(deduction.wrappedValue.amount);
        if amount.hasSuffix(".0") {
            amount = String(amount.dropLast(2))
        }
        self._inputAmount = State(initialValue: amount)

        self.onSave = onSave
    }

    var body: some View {
        HStack {
            TextField("Name", text: $deduction.name)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .onChange(of: deduction.name) { _ in
                self.onSave()
            }
            Spacer()
            TextField("Amount", text: $inputAmount)
            .keyboardType(.decimalPad)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .onChange(of: inputAmount) { newValue in
                if let value = Double(newValue) {
                    deduction.amount = value
                } else if inputAmount.isEmpty {
                    deduction.amount = 0
                }
                self.onSave()
            }
        }
    }
}

struct ContentView: View {
    @State private var deductions: [Spend] = []
    let monthlyRate: Double = 1000.0
    let updateInterval: TimeInterval = 1.0
    let startDate: Date = {
        var dateComponents = DateComponents()
        dateComponents.year = 2024
        dateComponents.month = 6
        dateComponents.day = 11
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0
        return Calendar.current.date(from: dateComponents) ?? Date()
    }()
    
    @State private var currentTime: Date = Date()

    var body: some View {
        VStack {
            Text("$\((currentTrickleValue() - totalDeductions()), specifier: "%.2f")")
                .monospacedDigit()
                .padding()
            List {
                ForEach($deductions) { $deduction in
                    SpendView(deduction: $deduction, onSave: saveDeductions)
                }
                .onDelete(perform: deleteDeduction)
            }
            .listStyle(InsetGroupedListStyle())
            Button("Add Spending") {
                let newDeduction = Spend(name: "", amount: 0.0)
                deductions.append(newDeduction)
                saveDeductions()
            }
        }
        .padding()
        .onAppear {
            loadDeductions()
            Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
                self.currentTime = Date()
            }
        }
    }

    private func currentTrickleValue() -> Double {
        let secondsElapsed = currentTime.timeIntervalSince(startDate)
        let perSecondRate = monthlyRate / (30 * 24 * 60 * 60)
        return perSecondRate * secondsElapsed
    }

    private func totalDeductions() -> Double {
        deductions.reduce(0) { $0 + $1.amount }
    }

    private func deleteDeduction(at offsets: IndexSet) {
        deductions.remove(atOffsets: offsets)
        saveDeductions()
    }

    private func loadDeductions() {
        if let data = UserDefaults.standard.data(forKey: "Deductions") {
            if let decoded = try? JSONDecoder().decode([Spend].self, from: data) {
                self.deductions = decoded
            }
        }
    }

    private func saveDeductions() {
        if let encoded = try? JSONEncoder().encode(deductions) {
            UserDefaults.standard.set(encoded, forKey: "Deductions")
        }
    }
}

#Preview {
    ContentView()
}

