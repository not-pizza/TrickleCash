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
    
    @State private var startingOffset: CGFloat = 0
    @State private var offset: CGFloat = 200
    @State private var isDragging = false
    @State private var foregroundHidden = false

    var body: some View {
        GeometryReader { geometry in
            let forgroundHiddenOffset: CGFloat = geometry.size.height - 100
            let forgroundShowingOffset: CGFloat = 200
            
            ZStack {
                BackgroundView(appData: $appData, onSettingsTapped: openSettings)
                
                ForegroundView(appData: $appData, hidden: foregroundHidden)
                    .offset(y: max(offset, 0))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if isDragging == false {
                                    startingOffset = self.offset
                                }
                                isDragging = true

                                let newOffset = startingOffset + gesture.translation.height
                                self.offset = min(max(newOffset, forgroundShowingOffset), forgroundHiddenOffset)
                            }
                            .onEnded { gesture in
                                isDragging = false
                                foregroundHidden = gesture.velocity.height > 0
                                withAnimation(.spring()) {
                                    if foregroundHidden {
                                        self.offset = forgroundHiddenOffset                                    } else {
                                        self.offset = forgroundShowingOffset
                                    }
                                }
                            }
                    )
            }.onChange(of: appData) { newAppData in
                let _ = newAppData.save()
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
    let hidden: Bool
    
    @State private var selectedDate: Date = Date()
    
    var body: some View {
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
        
        VStack {
            hidden ?
                Image(systemName: "chevron.up") :
                Image(systemName: "chevron.down")
            Spacer()
                
            
            CalendarStrip(selectedDate: $selectedDate) { date in
                // This closure is called when a date is selected
                selectedDate = date
            }
            
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
            TrickleView(appData: $appData, openSettings: {showingSettings = true})
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
