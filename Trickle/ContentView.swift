import SwiftUI
import WidgetKit

extension View {
    func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

    init(deduction: Binding<Spend>) {
        self._deduction = deduction

        var amount = String(deduction.wrappedValue.amount)
        if amount.hasSuffix(".0") {
            amount = String(amount.dropLast(2))
        }
        self._inputAmount = State(initialValue: amount)
    }

    var body: some View {
        HStack {
            TextField("Name", text: $deduction.name)
            .textFieldStyle(RoundedBorderTextFieldStyle())
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
            }
        }
    }
}

struct TrickleView: View {
    @Binding var appData: AppData
    var openSettings: () -> Void
    
    @State private var currentTime: Date = Date()
    
    @State private var offset: CGFloat = 200

    var body: some View {
        
        GeometryReader { geometry in
            ZStack {
                BackgroundView(appData: $appData, onSettingsTapped: openSettings)
                
                ForegroundView(appData: $appData, offset: $offset, geometry: geometry)
                    .offset(y: max(offset, 0))
            }
        }
    }
    
    func addSpend(spend: Spend) {
        appData = appData.addSpend(spend: spend).save()
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
    

    private func save() {
        let _ = appData.save()
    }
}


struct BackgroundView: View {
    @Binding var appData: AppData
    var onSettingsTapped: () -> Void
    
    var body: some View {
        let balance = appData.getTrickleBalance(time: Date())
        
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Color.clear
                    .frame(width: 24, height: 24)  // Dummy element
                Spacer()
                
                viewBalance(balance)
                    .font(.system(size: 30))
                
                Spacer()
                Button(action: onSettingsTapped) {
                    Image(systemName: "gear")
                        .foregroundColor(.primary)
                        .font(.system(size: 26))
                }
            }
            .padding()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct ForegroundView: View {
    @Binding var appData: AppData
    @Binding var offset: CGFloat
    var geometry: GeometryProxy
    
    @State private var startingOffset: CGFloat = 0
    @State private var selectedDate: Date = Date()
    @State private var isDragging = false
    @State private var hidden = false
    
    private func spendEventBindings() -> [Binding<Spend>] {
        var spendEvents = appData.events.indices.compactMap { index in
            if case .spend(let spend) = appData.events[index] {
                if Calendar.current.isDate(spend.dateAdded, inSameDayAs: selectedDate) {
                    return Binding(
                        get: { spend },
                        set: { appData.events[index] = Event.spend($0) }
                    )
                }
            }
            return nil
        }
        spendEvents.reverse()
        return spendEvents
    }
    
    var body: some View {
        let spendEvents = spendEventBindings()
        
        VStack {
            draggable
            
            List {
                ForEach(spendEvents, id: \.wrappedValue.id) { spend in
                    SpendView(deduction: spend)
                }
                .onDelete(perform: { indexSet in
                    for index in indexSet {
                        let spend = spendEvents[index]
                        appData = appData.deleteEvent(id: spend.id)
                    }
                })
            }
            .listStyle(InsetGroupedListStyle())
            .background(Color.white)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
    
    var draggable: some View {
        let forgroundHiddenOffset: CGFloat = geometry.size.height - 50
        let forgroundShowingOffset: CGFloat = geometry.size.height / 5
        
        return VStack(spacing: 10) {
            Button(action: {
                hidden = !hidden
                // TODO: deduplicate
                withAnimation(.spring()) {
                    if hidden {
                        endEditing()
                        self.offset = forgroundHiddenOffset
                    } else {
                        self.offset = forgroundShowingOffset
                    }
                }
            }) {
                hidden ?
                Image(systemName: "chevron.up") :
                Image(systemName: "chevron.down")
            }
            
            CalendarStrip(selectedDate: $selectedDate) { date in
                selectedDate = date
            }
            
            Button(action: {
                let newSpend = Spend(name: "", amount: 0)
                appData.events.append(.spend(newSpend))
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add spending")
                }
                .foregroundColor(.blue)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.blue.opacity(0.1))
        }
        // Adjust it if the screen size changes (e.g. keyboard appears or disappears
        .onChange(of: geometry.size.height) {new_height in
            let forgroundHiddenOffset: CGFloat = new_height - 50
            let forgroundShowingOffset: CGFloat = new_height / 5
            withAnimation(.spring()) {
                if hidden {
                    self.offset = forgroundHiddenOffset
                } else {
                    self.offset = forgroundShowingOffset
                }
            }
        }
        
    }
    
}

struct ContentView: View {
    @State var appData: AppData
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false
    @State private var tempMonthlyRate: String = ""
    
    init(initialAppData: AppData? = nil) {
        let initialAppData = initialAppData ?? AppData.load()
        _appData = State(initialValue: initialAppData)
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
                .onChange(of: tempMonthlyRate) { newTempMonthlyRate in
                    if let monthlyRate = Double(newTempMonthlyRate) {
                        appData.monthlyRate = monthlyRate
                        print("Changed the monthly rate to \(appData.monthlyRate)")
                        let _ = appData.save()
                    }
                }
            
            Button("Save Changes") {
                showingSettings = false
            }
        }
    }
    
    var body: some View {
        if showingSettings {
            settingsView
        }
        else {
            TrickleView(appData: $appData, openSettings: {
                showingSettings = true
                tempMonthlyRate = "\(String(format: "%.2f", appData.monthlyRate))"
            })
            .onChange(of: appData) { newAppData in
                let _ = newAppData.save()
            }
            .onAppear {
                appData = AppData.load()
            }.onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    appData = AppData.load()
                }
            }
           
        }
    }
}

#Preview {
    ContentView(initialAppData: AppData(
        monthlyRate: 1000,
        startDate: Date().startOfDay,
        events: [
            .spend(Spend(name: "7/11", amount: 30))
        ]
    ))
}
