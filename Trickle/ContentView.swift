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
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
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

struct ContentView: View {
    @State var appData: AppData
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false
    @State private var tempMonthlyRate: String = ""
    
    init(initialAppData: AppData? = nil) {
        let initialAppData = initialAppData ?? AppData.loadOrDefault()
        _appData = State(initialValue: initialAppData)
    }
    var settingsView: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Monthly Spending")
                            .font(.headline)
                        Text("Excluding bills and subscriptions")
                            .font(.subheadline)
                        TextField("Enter amount", text: $tempMonthlyRate)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: tempMonthlyRate) { newTempMonthlyRate in
                                if let monthlyRate = toDouble(newTempMonthlyRate) {
                                    appData.monthlyRate = monthlyRate
                                    let _ = appData.save()
                                }
                            }
                    }
                                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Start Date")
                            .font(.headline)
                        DatePicker("", selection: $appData.startDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()

                SpendingAvailability(monthlyRate: appData.monthlyRate)

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                showingSettings = false
            }) {
                Text("Save Changes")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
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
                appData = AppData.loadOrDefault()
            }.onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    appData = AppData.loadOrDefault()
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
