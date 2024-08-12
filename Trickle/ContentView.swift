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
    @State private var hidden = false

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let foregroundHiddenOffset: CGFloat = geometry.size.height - 120
                
                let initialforegroundShowingOffset = UIScreen.main.bounds.height / 6;
                let foregroundShowingOffset: CGFloat = geometry.size.height / 4.5

                
                ZStack {
                    VStack(alignment: .leading) {
                        ForegroundView(
                            appData: $appData,
                            offset: $offset,
                            geometry: geometry,
                            foregroundHiddenOffset: foregroundHiddenOffset,
                            foregroundShowingOffset: foregroundShowingOffset,
                            hidden: $hidden
                        )
                    }
                    .offset(y: max(offset, 0))
                    .zIndex(1)
                    // Adjust it if the screen size changes (e.g. keyboard appears or disappears
                    .onChange(of: hidden) {new_hidden in
                        let forgroundHiddenOffset: CGFloat = geometry.size.height - 100
                        let forgroundShowingOffset: CGFloat = geometry.size.height / 5
                        withAnimation(.spring()) {
                            if new_hidden {
                                self.offset = forgroundHiddenOffset
                            } else {
                                self.offset = forgroundShowingOffset
                            }
                        }
                    }
                    .onChange(of: geometry.size.height) {new_height in
                        let forgroundHiddenOffset: CGFloat = new_height - 100
                        let forgroundShowingOffset: CGFloat = new_height / 5
                        withAnimation(.spring()) {
                            if hidden {
                                self.offset = forgroundHiddenOffset
                            } else {
                                self.offset = forgroundShowingOffset
                            }
                        }
                    }
                    
                    
                    BackgroundView(
                        appData: $appData,
                        onSettingsTapped: openSettings,
                        foregroundShowingOffset: initialforegroundShowingOffset,
                        currentTime: currentTime
                    ).zIndex(0)
                }
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
