import Foundation
import SwiftUI

struct SpendBindingWithBuckets: Identifiable {
    let spend: Binding<Spend>
    let buckets: [MinimalBucketInfo]
    
    var id: UUID {
        spend.id
    }
}

struct ControlSpendAction: Equatable {
    static func == (lhs: ControlSpendAction, rhs: ControlSpendAction) -> Bool {
        lhs.appData == rhs.appData
    }
    
    let appData: AppData
    let add: (Spend) -> Void
    let update: (Spend) -> Void
    let remove: (UUID, Spend) -> Void
    let bucketValidAtDate: (UUID, Date) -> Bool
}

struct ForegroundView: View {
    var offset: CGFloat
    var foregroundHiddenOffset: Double
    var foregroundShowingOffset: Double
    var spends: [SpendWithMinimalBuckets]
    var tutorials: [TutorialItem]
    let tutorialsClosed: Bool
    var controlSpend: ControlSpendAction
    var closeTutorials: () -> Void
    var startDate: Date
    @Binding var hidden: Bool
    var colorScheme: ColorScheme
    var scenePhase: ScenePhase
    
    @State private var focusedSpendId: UUID?
    @State var chevronRotation: Double = 0
    
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private func spendEventBindings() -> [(date: Date, spends: [SpendBindingWithBuckets])] {
        let spendEventsByDay = Dictionary(
            grouping: spends,
            by: { $0.spend.dateAdded.startOfDay }
        )
        let spendEvents = spendEventsByDay.map { date, events in
            (
                date: date,
                spends: events.sorted(by: { $0.spend.dateAdded > $1.spend.dateAdded }).map({
                    s in SpendBindingWithBuckets(
                        spend: Binding(
                            get: { s.spend },
                            set: { newSpend in controlSpend.update(newSpend) }
                        ),
                        buckets: s.buckets
                    )
                })
            )
        }.sorted(by: {$0.date > $1.date})
        return spendEvents
    }
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    
    var body: some View {
        let spendEventsByDate = spendEventBindings()
        let spendList = ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(spendEventsByDate, id: \.date) { (date, spendEvents) in
                    Text(
                        dateFormatter.string(from: date)
                    )
                    .font(.subheadline)
                    .padding(.top, 10)
                    
                     ForEach(spendEvents) { spend in
                         SpendView(
                            deduction: spend.spend,
                            buckets: spend.buckets,
                            isFocused: focusedSpendId == spend.spend.wrappedValue.id,
                            startDate: startDate,
                            onDelete: { controlSpend.remove(spend.id, spend.spend.wrappedValue) },
                            bucketValidAtDate: {bucket, date in
                                controlSpend.bucketValidAtDate(bucket, date)
                            }
                         )
                         .transition(.move(edge: .top))
                         .padding(.horizontal, 15)
                    }

                    Spacer().frame(height: 10)
                }
            }.onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to:nil, from:nil, for:nil)
            }
        }

        return VStack {
            Button(action: {hidden = !hidden}) {
                HStack {
                    Spacer()
                    Image(systemName: "chevron.down")
                    Spacer()
                }
                .rotationEffect(.degrees(chevronRotation))
                .frame(height: 30)
            }.foregroundStyle(Color.primary)
            
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        addSpend
                    }
                    
                    Divider()
                    
                    if #available(iOS 18.0, *) {
                        spendList
                            .scrollContentBackground(Visibility.hidden)
                            .scrollDismissesKeyboard(.immediately)
                            .onScrollPhaseChange { phase, nextPhase in
                                if nextPhase == .decelerating {
                                    focusedSpendId = nil
                                }
                            }
                    }
                    else if #available(iOS 16.0, *) {
                        spendList
                            .scrollContentBackground(Visibility.hidden)
                    }
                    else {
                        spendList
                    }
                    
                    if !tutorialsClosed {
                        TutorialListView(tutorials: tutorials, closeTutorials: closeTutorials)
                    }
                    
                    Spacer().frame(height: offset)
                }
                .padding()
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.all)
            .onChange(of: hidden) { _ in
                if hidden == true {
                    focusedSpendId = nil
                }
            }
        }.onChange(of: hidden, perform: {_ in
            chevronRotation = hidden ? 180 : 0
        })
        .animation(.spring(), value: chevronRotation)
    }
    
    var addSpend: some View {
        return AddTransactionButton(isIncome: false, action: {
            withAnimation(.spring()) {
                let newSpend = Spend(
                    name: "",
                    amount: 10,
                    dateAdded: Date()
                )
                controlSpend.add(newSpend)
                focusedSpendId = newSpend.id
            }
            hidden = false
        })
    }
    
    struct AddTransactionButton: View {
        let isIncome: Bool
        let action: () -> Void
        @State private var animate = false
        
        var body: some View {
            Button(action: {
                action()
                animate = true
                
                // Reset the animation state without animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.none) {
                        animate = false
                    }
                }
            }) {
                HStack {
                    ZStack {
                        // Ripple Effect
                        Circle()
                            .stroke(isIncome ? Color.green : Color.red, lineWidth: 2)
                            .frame(width: 27, height: 27)
                            .scaleEffect(animate ? 2.5 : 1)
                            .opacity(animate ? 0 : 1)
                            .animation(animate ? .easeOut(duration: 0.6) : .none, value: animate)
                        
                        // Icon
                        Image(systemName: isIncome ? "arrow.up.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 27))
                            .foregroundColor(isIncome ? .green : .red)
                            .rotationEffect(animate ? Angle(degrees: 360) : Angle(degrees: 0))
                            //.scaleEffect(animate ? 1.5 : 1)
                            .animation(animate ? .easeInOut(duration: 0.6) : .none, value: animate)
                    }

                    Text(isIncome ? "Windfall" : "Spending")
                        .font(.headline)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(2)
        }
    }
}

#Preview {
    ZStack {
        Color.green.ignoresSafeArea()
        
        ForegroundView(
            offset: UIScreen.main.bounds.height / 5,
            foregroundHiddenOffset: UIScreen.main.bounds.height - 50,
            foregroundShowingOffset: UIScreen.main.bounds.height / 5,
            spends: [],
            tutorials: [],
            tutorialsClosed: false,
            controlSpend: ControlSpendAction(
                appData: AppData(
                    monthlyRate: 1000,
                    startDate: Date().startOfDay,
                    events: [
                        .spend(Spend(name: "7/11", amount: 30))
                    ],
                    watchedHomeSceenWidgetTutorial: nil,
                    watchedLockSceenWidgetTutorial: nil,
                    watchedShortcutTutorial: nil,
                    tutorialsPaneLastClosed: nil
                ),
                add: {_ in ()},
                update: {_ in ()},
                remove: {_, _ in ()},
                bucketValidAtDate: {_, _ in true}
            ),
            closeTutorials: {},
            startDate: Date().startOfDay,
            hidden: .constant(false),
            colorScheme: .dark,
            scenePhase: .active
        ).offset(y: 150)
    }
}
