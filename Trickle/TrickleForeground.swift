import Foundation
import SwiftUI

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
            Section {
                ForEach(spendEvents, id: \.wrappedValue.id) { spend in
                    SpendView(deduction: spend)
                        .transition(.move(edge: .top))
                }
                .onDelete(perform: { indexSet in
                    for index in indexSet {
                        let spend = spendEvents[index]
                        appData = appData.deleteEvent(id: spend.id)
                    }
                })
                .listRowSeparator(.hidden)
                .listRowSeparatorTint(.clear)
                .listRowBackground(Rectangle()
                    .background(.clear)
                    .foregroundColor(.clear)
                )
            }
            .listStyle(.inset)
        }

        return ZStack {
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
            }*/
            
            CalendarStrip(selectedDate: $selectedDate) { date in
                selectedDate = date
            }
            
            Button(action: {
                withAnimation(.spring()) { // Add animation wrapper
                    let newSpend = Spend(
                        name: "",
                        amount: 0,
                        dateAdded:
                            selectedDate.startOfDay == Date().startOfDay ?
                            Date() :
                            selectedDate
                    )
                    appData.events.append(.spend(newSpend))
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
                foregroundShowingOffset: UIScreen.main.bounds.height / 5
            ).offset(y: 150)
        }
    }
}
