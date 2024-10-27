import SwiftUI
import WidgetKit
import AlertToast

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

    @State private var lastDeletedSpendId: UUID?
    @State private var lastDumpedBucket: (Bucket, Double)?
    @State private var lastDeletedBucket: (Bucket, Double)?
    
    
    var controlSpend: ControlSpendAction {
        ControlSpendAction(
            appData: appData,
            add: { appData = appData.addSpend($0) },
            update: { appData = appData.updateSpend($0) },
            remove: { appData = appData.deleteEvent(id: $0); lastDeletedSpendId = $0 },
            bucketValidAtDate: {bucket, date in appData.getAppState(asOf: date).buckets[bucket] != nil}
        )
    }

    var controlBucket: ControlBucketAction {
        ControlBucketAction(
            appData: appData,
            add: { appData = appData.addBucket($0) },
            update: { appData = appData.updateBucket($0, $1) },
            dump: { appData = appData.dumpBucket($0); lastDumpedBucket = ($1, $2) },
            delete: { appData = appData.deleteBucket($0); lastDeletedBucket = ($1, $2) }
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
                            tutorials: getTutorialItems(appData: $appData),
                            tutorialsClosed: appData.tutorialsPaneLastClosed != nil,
                            controlSpend: controlSpend,
                            closeTutorials: {appData.tutorialsPaneLastClosed = Date()},
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
                        controlBucket: controlBucket,
                        onSettingsTapped: openSettings,
                        foregroundShowingOffset: initialforegroundShowingOffset,
                        foregroundHidden: hidden
                    ).zIndex(0)
                }
            }
        }
        .toast(isPresenting: Binding(get: {lastDeletedSpendId != nil}, set: {_ in lastDeletedSpendId = nil}), duration: 4) {
            AlertToast(displayMode: .hud, type: .error(.red), title: "Spending deleted")
        }
        .toast(isPresenting: Binding(get: {lastDeletedBucket != nil}, set: {_ in lastDeletedBucket = nil}), duration: 8) {
            if let lastDeletedBucket = lastDeletedBucket {
                let (bucket, amount) = lastDeletedBucket
                let amountString = formatCurrencyNoDecimals(amount)
                return AlertToast(displayMode: .hud, type: .error(.red), title: "Bucket \(bucket.name.smartCapitalized) deleted")
            }
            else {
                return AlertToast(displayMode: .hud, type: .error(.red), title: "Bucket deleted")
            }
        }
        .toast(isPresenting: Binding(get: {lastDumpedBucket != nil}, set: {_ in lastDumpedBucket = nil}), duration: 8) {
            if let lastDumpedBucket = lastDumpedBucket {
                let (bucket, amount) = lastDumpedBucket
                let amountString = formatCurrencyNoDecimals(amount)
                return AlertToast(displayMode: .hud, type: .complete(.green), title: "\(amountString) from `\(bucket.name.smartCapitalized)` dumped into main balance")
            }
            else {
                return AlertToast(displayMode: .hud, type: .complete(.green), title: "Bucket dumped into main balance")
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
        watchedShortcutTutorial: nil,
        tutorialsPaneLastClosed: nil
    ))
}
