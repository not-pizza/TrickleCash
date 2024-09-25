import Foundation
import SwiftUI

struct ForegroundView: View {
    @Binding var appData: AppData
    @Binding var offset: CGFloat
    var geometry: GeometryProxy
    var foregroundHiddenOffset: Double
    var foregroundShowingOffset: Double
    @Binding var hidden: Bool
    
    @State private var startingOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var focusedSpendId: UUID?
    @State private var chevronRotation: Double = 0
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    @State private var completedTutorials: Set<UUID> = []
    
    let tutorials = [
        TutorialItem(videoName: "add-home-screen-widget", videoTitle: "Add a Home Screen Widget"),
        TutorialItem(videoName: "add-lock-screen-widget", videoTitle: "Add a Lock Screen Widget"),
    ]
    
    private func spendEventBindings() -> [(date: Date, spends: [Binding<Spend>])] {
        let spendEventsByDay = Dictionary(grouping: appData.getSpendEventsAfterStartDate(), by: { $0.dateAdded.startOfDay })
        let spendEvents = spendEventsByDay.map { date, events in
            (date: date, spends: events.sorted(by: { $0.dateAdded < $1.dateAdded }).map({
                spend in Binding(
                    get: { spend },
                    set: { newSpend in appData = appData.updateSpend(newSpend) }
                )
            }))
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
            LazyVStack(alignment: .leading) {
                ForEach(spendEventsByDate, id: \.date) { (date, spendEvents) in
                    
                    Text(
                        dateFormatter.string(from: date)
                    )
                    .font(.subheadline)
                    .padding(.top, 10)
                    
                    ForEach(spendEvents, id: \.wrappedValue.id) { spend in
                        SpendView(
                            deduction: spend,
                            isFocused: focusedSpendId == spend.wrappedValue.id,
                            onDelete: { appData = appData.deleteEvent(id: spend.id) }
                        ).padding(.vertical, 2)
                            .transition(.move(edge: .top))
                    }
                    .onDelete(perform: { indexSet in
                        for index in indexSet {
                            let spend = spendEvents[index]
                            appData = appData.deleteEvent(id: spend.id)
                        }
                    })
                }
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
                    addSpend
                    if #available(iOS 16.0, *) {
                        spendList.scrollContentBackground(.hidden)
                    }
                    else {
                        spendList
                    }
                    
                    TutorialListView(completedTutorials: $completedTutorials, tutorials: tutorials)
                    
                    Spacer().frame(height: offset)
                }
                .padding()
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.all)
            .onChange(of: hidden) { _ in
                focusedSpendId = nil
            }
        }.onChange(of: hidden, perform: {_ in
            chevronRotation = hidden ? 180 : 0
        })
        .animation(.spring(), value: chevronRotation)
    }
    
    var addSpend: some View {
        return VStack(spacing: 10) {
            Button(action: {
                withAnimation(.spring()) {
                    let newSpend = Spend(
                        name: "",
                        amount: 0,
                        dateAdded: Date()
                    )
                    appData = appData.addSpend(newSpend)
                    focusedSpendId = newSpend.id
                }
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
    }
}

#Preview {
    GeometryReader { geometry in
        ZStack {
            Color.green.ignoresSafeArea()
            
            ForegroundView(
                appData: .constant(AppData(
                    monthlyRate: 1000,
                    startDate: Date().startOfDay,
                    events: [
                        .spend(Spend(name: "7/11", amount: 30))
                    ]
                )),
                offset: .constant(UIScreen.main.bounds.height / 5),
                geometry: geometry,
                foregroundHiddenOffset: UIScreen.main.bounds.height - 50,
                foregroundShowingOffset: UIScreen.main.bounds.height / 5,
                hidden: .constant(false)
            ).offset(y: 150)
        }
    }
}
