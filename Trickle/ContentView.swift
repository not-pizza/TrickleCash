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
        var amount = String(deduction.wrappedValue.amount)
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
            .keyboardType(.numbersAndPunctuation)
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
    @State private var monthlyRate: Double
    @State private var startDate: Date
    @State private var currentTime: Date = Date()
    @State private var tempMonthlyRate: String = ""
    @State private var showingSettings = false

    init() {
        let defaults = UserDefaults.standard
        let monthlyRate: Double
        if let rate = defaults.object(forKey: "MonthlyRate") as? Double {
            monthlyRate = rate
        } else {
            monthlyRate = 1000.0  // Default value when the key doesn't exist
        }
        _monthlyRate = State(initialValue: monthlyRate)

        _startDate = State(initialValue: UserDefaults.standard.object(forKey: "StartDate") as? Date ?? Date())
    }

    var body: some View {
        NavigationView {
            ZStack {
                if showingSettings {
                    settingsView
                } else {
                    mainContentView
                }
                
                if !showingSettings {
                    // Floating add button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                let newDeduction = Spend(name: "", amount: 0.0)
                                deductions.append(newDeduction)
                                saveDeductions()
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.blue)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarItems(leading:
                Button(action: {
                    showingSettings = true
                    tempMonthlyRate = "\(monthlyRate)"
                }) {
                    Image(systemName: "gear")
                }
            )
            .navigationBarTitle("Spending Tracker", displayMode: .inline)
        }
        .onAppear {
            loadDeductions()
            setupTimer()
        }
    }
    
    var settingsView: some View {
        Form {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                .onChange(of: startDate) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "StartDate")
                }
            
            TextField("Monthly Rate", text: $tempMonthlyRate)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Save Changes") {
                // Try to convert the temporary rate to a Double
                if let rate = Double(tempMonthlyRate) {
                    monthlyRate = rate
                    UserDefaults.standard.set(rate, forKey: "MonthlyRate")
                    // Feedback to the user that saving was successful
                } else {
                    // Handle invalid input, e.g., revert to the last saved rate or show an error
                    tempMonthlyRate = "\(monthlyRate)" // Revert to the last valid rate
                }
                showingSettings = false // Optionally close settings after saving
            }
        }
    }

    var mainContentView: some View {
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
        }
    }

    private func setupTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func currentTrickleValue() -> Double {
        let secondsElapsed = currentTime.timeIntervalSince(startDate)
        let perSecondRate = monthlyRate / (30.416 * 24 * 60 * 60)
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
                deductions = decoded
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
