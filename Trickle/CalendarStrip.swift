import Foundation
import SwiftUI

struct CalendarStrip: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    @Binding var focusedSpendId: UUID?
    
    @State private var showDatePicker = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    
    var datePicker: some View {
        DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(GraphicalDatePickerStyle())
            .onChange(of: selectedDate) { newValue in
                onDateSelected(newValue)
                showDatePicker = false
            }
            .padding()
    }
    
    var body: some View {
        HStack {
            Button(action: {
                selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate)!
                onDateSelected(selectedDate)
                focusedSpendId = nil
            }) {
                Image(systemName: "chevron.left")
            }.buttonStyle(.plain)
            
            Spacer()
            
            Button(action: {
                showDatePicker.toggle()
                focusedSpendId = nil
            }) {
                Text("\(dateFormatter.string(from: selectedDate))")
                    .font(.headline)
            }.buttonStyle(.plain)
            .sheet(isPresented: $showDatePicker) {
                if #available(iOS 16.0, *) {
                    datePicker
                        .presentationDetents([.medium])
                }
                else {
                    datePicker
                }
            }
            
            Spacer()
            
            Button(action: {
                selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate)!
                onDateSelected(selectedDate)
                focusedSpendId = nil
            }) {
                Image(systemName: "chevron.right")
            }.buttonStyle(.plain)
        }
        .padding()
    }
}
