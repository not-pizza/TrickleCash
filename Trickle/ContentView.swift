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

enum UpdatableAppData: Codable {
    case v1(AppData)
    
    var appData: AppData {
        switch self {
        case .v1(let data):
            return data
        }
    }
}

struct CalendarStrip: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE\nd"
        return formatter
    }()
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(-3...3, id: \.self) { offset in
                    let date = calendar.date(byAdding: .day, value: offset, to: Date())!
                    VStack {
                        Text(dateFormatter.string(from: date))
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 50, height: 50)
                    .background(date.startOfDay == selectedDate.startOfDay ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(date.startOfDay == selectedDate.startOfDay ? Color.white : Color.primary)
                    .cornerRadius(8)
                    .onTapGesture {
                        selectedDate = date
                        onDateSelected(date)
                    }
                }
            }
            .padding()
        }
    }
}

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
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
    @State private var selectedDate: Date = Date()

    init() {
        let initialAppData = Self.loadAppData()
        _appData = State(initialValue: initialAppData)
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
            appData = Self.loadAppData()
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
        let spendEvents = appData.events.indices.compactMap { index in
            if case .spend(let spend) = appData.events[index] {
                if Calendar.current.isDate(spend.dateAdded, inSameDayAs: selectedDate) {
                    return Binding(
                        get: { spend },
                        set: { appData.events[index] = Event.spend($0) }
                    )
                }
            }
            return nil
        };
        
        return VStack {
            Text("$\((currentTrickleValue() - totalDeductions()), specifier: "%.2f")")
                .monospacedDigit()
            
            CalendarStrip(selectedDate: $selectedDate) { date in
                // This closure is called when a date is selected
                selectedDate = date
            }
            
            List {
                ForEach(spendEvents, id: \.wrappedValue.id) { spend in
                    SpendView(deduction: spend, onSave: saveAppData)
                }
                .onDelete(perform: { indexSet in
                    for index in indexSet {
                        let spend = spendEvents[index]
                        deleteEvent(id: spend.id)
                    }
                })
            }
            .listStyle(InsetGroupedListStyle())
        };
    }
    

    var addSpendingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    let newSpend = Spend(name: "", amount: 0.0, dateAdded: selectedDate)
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
    
    private func deleteEvent(id: UUID) {
        appData.events.removeAll { $0.id == id }
        saveAppData()
    }

    private static func loadAppData() -> AppData {
        let defaults = UserDefaults.standard
        
        if let savedData = defaults.data(forKey: "AppData"),
           let decodedData = try? JSONDecoder().decode(UpdatableAppData.self, from: savedData) {
            return decodedData.appData
        } else {
            // Return default values
            return AppData(
                monthlyRate: 1000.0,
                startDate: Date(),
                events: []
            )
        }
    }

    private func saveAppData() {
        if let monthlyRate = Double(tempMonthlyRate) {
            appData.monthlyRate = monthlyRate
            UserDefaults.standard.set(monthlyRate, forKey: "MonthlyRate")
        } else {
            tempMonthlyRate = "\(appData.monthlyRate)" // Revert to the last valid rate
        }

        let updatableAppData = UpdatableAppData.v1(appData)
        if let encoded = try? JSONEncoder().encode(updatableAppData) {
            UserDefaults.standard.set(encoded, forKey: "AppData")
        }
    }
}

#Preview {
    ContentView()
}
