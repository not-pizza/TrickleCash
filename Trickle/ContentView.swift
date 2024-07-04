import SwiftUI

struct AppData: Codable {
    var monthlyRate: Double
    var startDate: Date
    var events: [Event]
}

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
    @State private var appData: AppData
    @State private var currentTime: Date = Date()
    @State private var tempMonthlyRate: String = ""
    @State private var showingSettings = false

    init() {
        let defaults = UserDefaults.standard
        
        if let savedData = defaults.data(forKey: "AppData"),
           let decodedData = try? JSONDecoder().decode(AppData.self, from: savedData) {
            // If we have saved data, use it
            _appData = State(initialValue: decodedData)
        } else {
            // If no saved data, initialize with default values
            let defaultMonthlyRate: Double = 1000.0
            let defaultStartDate: Date = Date()
            let defaultEvents: [Event] = []
            
            _appData = State(initialValue: AppData(
                monthlyRate: defaultMonthlyRate,
                startDate: defaultStartDate,
                events: defaultEvents
            ))
        }
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
                            tempMonthlyRate = "\(appData.monthlyRate)"
                        }) {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: {
                            saveAppData()
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
            loadAppData()
            setupTimer()
        }
    }
    
    var settingsView: some View {
        Form {
            DatePicker("Start Date", selection: $appData.startDate, displayedComponents: .date)
                .onChange(of: appData.startDate) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "StartDate")
                }
            
            TextField("Monthly Rate", text: $tempMonthlyRate)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Save Changes") {
                saveAppData()
                showingSettings = false
            }
        }
    }

    var mainContentView: some View {
        VStack {
            Text("$\((currentTrickleValue() - totalDeductions()), specifier: "%.2f")")
                .monospacedDigit()
            List {
                ForEach($appData.events) { $event in
                    if case .spend(var spend) = event {
                        SpendView(deduction: Binding(
                            get: { spend },
                            set: { newValue in
                                spend = newValue
                                event = .spend(spend)
                            }
                        ), onSave: saveAppData)
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
                    appData.events.append(.spend(newSpend))
                    saveAppData()
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

    private func setupTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func currentTrickleValue() -> Double {
        let secondsElapsed = currentTime.timeIntervalSince(appData.startDate)
        let perSecondRate = appData.monthlyRate / (30.416 * 24 * 60 * 60)
        return perSecondRate * secondsElapsed
    }

    private func totalDeductions() -> Double {
        appData.events.reduce(0) { total, event in
            if case .spend(let spend) = event {
                return total + spend.amount
            }
            return total
        }
    }
    
    private func deleteEvent(at offsets: IndexSet) {
        appData.events.remove(atOffsets: offsets)
        saveAppData()
    }

    private func loadAppData() {
        if let data = UserDefaults.standard.data(forKey: "AppData") {
            if let decoded = try? JSONDecoder().decode(AppData.self, from: data) {
                appData = decoded
            }
        }
    }

    private func saveAppData() {
        if let monthlyRate = Double(tempMonthlyRate) {
            appData.monthlyRate = monthlyRate
            UserDefaults.standard.set(monthlyRate, forKey: "MonthlyRate")
        } else {
            tempMonthlyRate = "\(appData.monthlyRate)" // Revert to the last valid rate
        }

        if let encoded = try? JSONEncoder().encode(appData) {
            UserDefaults.standard.set(encoded, forKey: "AppData")
        }
    }
}

#Preview {
    ContentView()
}
