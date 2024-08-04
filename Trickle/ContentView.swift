import SwiftUI
import WidgetKit

extension View {
    func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
}

struct TrickleView: View {
    @Binding var appData: AppData
    var openSettings: () -> Void
    
    @State private var currentTime: Date = Date()
    
    @State private var offset: CGFloat = 200
    
    @State private var initialForgroundShowingOffset: CGFloat?
    @State private var setInitialForgroundShowingOffset: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let forgroundHiddenOffset: CGFloat = geometry.size.height - 100
            let forgroundShowingOffset: CGFloat = geometry.size.height / 5
            
            ZStack {
                ForegroundView(
                    appData: $appData,
                    offset: $offset,
                    geometry: geometry,
                    foregroundHiddenOffset: forgroundHiddenOffset,
                    foregroundShowingOffset: forgroundShowingOffset
                )
                    .offset(y: max(offset, 0))
                    .zIndex(1)
                
                BackgroundView(
                    appData: $appData,
                    onSettingsTapped: openSettings,
                    forgroundShowingOffset: initialForgroundShowingOffset ?? forgroundShowingOffset,
                    currentTime: currentTime
                ).zIndex(0)
            }.onAppear(perform: {
                    if !setInitialForgroundShowingOffset {
                        initialForgroundShowingOffset = forgroundShowingOffset
                    }
                }
            )
        }.onAppear() {
            setupTimer()
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

struct CircularProgressView: View {
    let progress: Double
    let balance: Double
    
    @Environment(\.colorScheme) var colorScheme
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    var body: some View {
        let lineWidth: CGFloat = 8
        return ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.3)
                .foregroundColor(backgroundColor)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(backgroundColor)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            VStack {
                viewBalance(balance)
                    .font(.system(size: 30))
            }
        }
    }
}

struct BackgroundView: View {
    @Binding var appData: AppData
    var onSettingsTapped: () -> Void
    var forgroundShowingOffset: CGFloat
    var currentTime: Date
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let balance = appData.getTrickleBalance(time: currentTime)
        
        ZStack {
            balanceBackground(balance, colorScheme: colorScheme).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Color.clear
                        .frame(width: 24, height: 24)  // Dummy element
                    Spacer()
                    
                    CircularProgressView(progress: appData.getPercentThroughCurrentCent(time: currentTime), balance: balance)
                        .frame(width: forgroundShowingOffset * 0.8, height: forgroundShowingOffset * 0.8)
                    
                    
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
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct ForegroundView: View {
    @Binding var appData: AppData
    @Binding var offset: CGFloat
    var geometry: GeometryProxy
    var foregroundHiddenOffset: Double
    var foregroundShowingOffset: Double
    
    @State private var startingOffset: CGFloat = 0
    @State private var selectedDate: Date = Date()
    @State private var isDragging = false
    @State private var hidden = false
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
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
        let spendList = List {
            ForEach(spendEvents, id: \.wrappedValue.id) { spend in
                SpendView(deduction: spend)
            }
            .onDelete(perform: { indexSet in
                for index in indexSet {
                    let spend = spendEvents[index]
                    appData = appData.deleteEvent(id: spend.id)
                }
            })
            .listStyle(InsetGroupedListStyle())
        }

        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack {
                draggable
                
                if #available(iOS 16.0, *) {
                    spendList.scrollContentBackground(.hidden)
                }
                else {
                    spendList
                }
                
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.all)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                selectedDate = Date()
            }
        }
    }
    
    
    var draggable: some View {
        return VStack(spacing: 10) {
            Color.clear
                .frame(width: 10, height: 10)
            
            /*Button(action: {
                hidden = !hidden
                // TODO: deduplicate
                withAnimation(.spring()) {
                    if hidden {
                        endEditing()
                        self.offset = foregroundHiddenOffset
                    } else {
                        self.offset = foregroundShowingOffset
                    }
                }
            }) {
                hidden ?
                Image(systemName: "chevron.up") :
                Image(systemName: "chevron.down")
            }.buttonStyle(.plain)*/
            
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
