import SwiftUI

struct Deduction: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
}

struct DeductionView: View {
    @Binding var deduction: Deduction
    @State private var inputAmount: String

    init(deduction: Binding<Deduction>) {
        self._deduction = deduction
        self._inputAmount = State(initialValue: String(deduction.wrappedValue.amount))
    }

    var body: some View {
        HStack {
            TextField("Name", text: $deduction.name, onCommit: {
                saveDeductions()
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            Spacer()
            TextField("Amount", text: $inputAmount, onCommit: {
                if let value = Double(inputAmount) {
                    deduction.amount = value
                } else if inputAmount.isEmpty {
                    deduction.amount = 0
                }
                saveDeductions()
            })
            .keyboardType(.decimalPad)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .onChange(of: inputAmount) { newValue in
                if let value = Double(newValue) {
                    deduction.amount = value
                }
            }
        }
    }

    private func saveDeductions() {
        // Save the deductions in the parent view's context
        // This function should trigger the parent view's save functionality
    }
}

struct ContentView: View {
    @State private var deductions: [Deduction] = []
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
                    DeductionView(deduction: $deduction)
                }
                .onDelete(perform: deleteDeduction)
            }
            .listStyle(InsetGroupedListStyle())
            Button("Add Deduction") {
                let newDeduction = Deduction(name: "", amount: 0.0)
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
            if let decoded = try? JSONDecoder().decode([Deduction].self, from: data) {
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
