import SwiftUI

struct Deduction: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
}

struct ContentView: View {
    @State private var deductions: [Deduction] = []
    let monthlyRate: Double = 1000.0  // Example rate
    let updateInterval: TimeInterval = 0.01  // Updates every second
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
            Text("$\((currentTrickleValue() - totalDeductions()), specifier: "%.5f")")
                .monospacedDigit()
                .padding()
            List {
                ForEach($deductions) { $deduction in
                    HStack {
                        TextField("Name", text: $deduction.name, onCommit: {
                            saveDeductions()
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        Spacer()
                        TextField("Amount", value: $deduction.amount, formatter: NumberFormatter(), onCommit: {
                            saveDeductions()
                        })
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .onChange(of: deduction.name) { _ in
                        saveDeductions()
                    }
                    .onChange(of: deduction.amount) { _ in
                        saveDeductions()
                    }
                }
                .onDelete(perform: deleteDeduction)
            }
            .listStyle(InsetGroupedListStyle())
            Button("Add Deduction") {
                // Adding a dummy deduction for demonstration; replace with actual user input in practice
                let newDeduction = Deduction(name: "New Sample", amount: 50.0)
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
