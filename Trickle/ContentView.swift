import SwiftUI

struct Spend: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var dateAdded: Date = Date()
}

enum Event: Codable, Identifiable {
    case spend(Spend)
    
    var id: UUID {
        switch self {
        case .spend(let spend):
            return spend.id
        }
    }
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
    @State private var events: [Event] = []
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
                    addSpendingButton
                }
            }
            .navigationBarItems(leading:
                Group {
                    if !showingSettings {
                        Button(action: {
                            showingSettings = true
                            tempMonthlyRate = "\(monthlyRate)"
                        }) {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: {
                            saveSettings()
                            showingSettings = false
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            )
            .navigationBarTitle(showingSettings ? "Settings" : "Cash", displayMode: .inline)
        }
        .onAppear {
            loadEvents()
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
                saveSettings()
                showingSettings = false
            }
        }
    }

    var mainContentView: some View {
        VStack {
            Text("$\((currentTrickleValue() - totalDeductions()), specifier: "%.2f")")
                .monospacedDigit()
            List {
                ForEach($events) { $event in
                    if case .spend(var spend) = event {
                        SpendView(deduction: Binding(
                            get: { spend },
                            set: { newValue in
                                spend = newValue
                                event = .spend(spend)
                            }
                        ), onSave: saveEvents)
                    }
                }
                .onDelete(perform: deleteEvent)
            }
            .listStyle(InsetGroupedListStyle())
        }
    }

    var addSpendingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    let newSpend = Spend(name: "", amount: 0.0)
                    events.append(.spend(newSpend))
                    saveEvents()
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

    private func saveSettings() {
        if let rate = Double(tempMonthlyRate) {
            monthlyRate = rate
            UserDefaults.standard.set(rate, forKey: "MonthlyRate")
        } else {
            tempMonthlyRate = "\(monthlyRate)" // Revert to the last valid rate
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
        events.reduce(0) { total, event in
            if case .spend(let spend) = event {
                return total + spend.amount
            }
            return total
        }
    }

    private func deleteEvent(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
        saveEvents()
    }

    private func loadEvents() {
        if let data = UserDefaults.standard.data(forKey: "Events") {
            if let decoded = try? JSONDecoder().decode([Event].self, from: data) {
                events = decoded
            }
        }
    }

    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: "Events")
        }
    }
}

#Preview {
    ContentView()
}
