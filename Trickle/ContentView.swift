import SwiftUI
import WidgetKit

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
                ForEach(-5...0, id: \.self) { offset in
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
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let initialAppData = loadAppData()
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
                            save()
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
            appData = loadAppData()
            setupTimer()
        }.onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                appData = loadAppData()
            }
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
                save()
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
                    SpendView(deduction: spend, onSave: save)
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
                    addSpend(spend: newSpend)
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
    
    func addSpend(spend: Spend) {
        appData.events.append(.spend(spend))
        save()
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
        save()
    }

    private func save() {
        saveAppData(appData: appData)
    }
}

#Preview {
    ContentView()
}
