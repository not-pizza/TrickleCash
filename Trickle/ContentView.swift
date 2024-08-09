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
        NavigationView {
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
    }

    private func setupTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            currentTime = Date()
        }
    }
}

struct ContentView: View {
    @State var appData: AppData
    @Environment(\.scenePhase) private var scenePhase
    @State private var tempMonthlyRate: String = ""
    
    init(initialAppData: AppData) {
        _appData = State(initialValue: initialAppData)
    }
    
    var body: some View {
        TrickleView(appData: $appData, openSettings: {
            tempMonthlyRate = "\(String(format: "%.2f", appData.getMonthlyRate()))"
        })
        .onChange(of: appData) { newAppData in
            print("appdata changed!")
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

#Preview {
    ContentView(initialAppData: AppData(
        monthlyRate: 1000,
        startDate: Date().startOfDay,
        events: [
            .spend(Spend(name: "7/11", amount: 30))
        ]
    ))
}
