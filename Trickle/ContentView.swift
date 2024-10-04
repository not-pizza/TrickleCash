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
    
    @State private var offset: CGFloat = 200
    @State private var hidden = false
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    
    var tutorials: [TutorialItem] {
        var tutorials: [TutorialItem] = []
        tutorials.append(
            TutorialItem(
                videoName: "add-home-screen-widget",
                videoTitle: "Add a Home Screen Widget",
                watched: Binding(get: {appData.watchedHomeSceenWidgetTutorial}, set: {appData.watchedHomeSceenWidgetTutorial = $0})
            )
        )
        tutorials.append(
            TutorialItem(
                videoName: "add-lock-screen-widget",
                videoTitle: "Add a Lock Screen Widget",
                watched: Binding(get: {appData.watchedLockSceenWidgetTutorial}, set: {appData.watchedLockSceenWidgetTutorial = $0})
            )
        )
        tutorials.append(
            TutorialItem(
                videoName: "Add a shortcut to trickle",
                videoTitle: "Add iPhone Payments Automatically",
                watched: Binding(get: {appData.watchedShortcutTutorial}, set: {appData.watchedShortcutTutorial = $0})

            )
        )
        return tutorials
    }
    
    var controlSpend: ControlSpendAction {
        ControlSpendAction(
            appData: appData,
            add: { appData = appData.addSpend($0) },
            update: { appData = appData.updateSpend($0) },
            remove: { appData = appData.deleteEvent(id: $0) },
            bucketValidAtDate: {bucket, date in appData.getAppState(asOf: date).buckets[bucket] != nil}
        )
    }

    var body: some View {
        let currentTime = Date()
        let startDate = appData.getStartDate(asOf: currentTime)
        let appState = appData.getAppState(asOf: currentTime)
        let spends = appState.spends.map({spendWithBucket in
            SpendWithMinimalBuckets(
                spend: spendWithBucket.spend,
                buckets: spendWithBucket.buckets.map({bucket in
                    MinimalBucketInfo(
                        id: bucket.id,
                        name: bucket.bucket.name
                    )
                })
            )
        })

        return NavigationView {
            GeometryReader { geometry in
                let foregroundHiddenOffset: CGFloat = geometry.size.height - 120
                
                let initialforegroundShowingOffset = UIScreen.main.bounds.height / 6;
                let foregroundShowingOffset: CGFloat = geometry.size.height / 4.5

                
                ZStack {
                    VStack(alignment: .leading) {
                        ForegroundView(
                            offset: offset,
                            foregroundHiddenOffset: foregroundHiddenOffset,
                            foregroundShowingOffset: foregroundShowingOffset,
                            spends: spends,
                            tutorials: tutorials,
                            controlSpend: controlSpend,
                            startDate: startDate,
                            hidden: $hidden,
                            colorScheme: colorScheme,
                            scenePhase: scenePhase
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
                        foregroundHidden: hidden
                    ).zIndex(0)
                }
            }
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
        ],
        watchedHomeSceenWidgetTutorial: nil,
        watchedLockSceenWidgetTutorial: nil,
        watchedShortcutTutorial: nil
    ))
}
