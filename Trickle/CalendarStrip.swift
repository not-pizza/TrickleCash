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
    
    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }
    
    private var todayDirection: ComparisonResult {
        calendar.compare(Date(), to: selectedDate, toGranularity: .day)
    }
    
    var body: some View {
        HStack {
            Group {
                if todayDirection == .orderedAscending {
                    todayButton
                } else {
                    Spacer().frame(minWidth: 0)
                }
            }
            .frame(width: 80)  // Adjust this width as needed
            
            Button(action: {
                showDatePicker.toggle()
                focusedSpendId = nil
            }) {
                HStack {
                    Image(systemName: "calendar")
                    Text("\(dateFormatter.string(from: selectedDate))")
                        .font(.headline)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDatePicker) {
                if #available(iOS 16.0, *) {
                    datePicker
                        .presentationDetents([.medium])
                } else {
                    datePicker
                }
            }
            
            Group {
                if todayDirection == .orderedDescending {
                    todayButton
                } else {
                    Spacer().frame(minWidth: 0)
                }
            }
            .frame(width: 80)  // Adjust this width as needed
        }
        .padding()
    }
    
    private var todayButton: some View {
        Button(action: {
            selectedDate = Date()
            onDateSelected(selectedDate)
            focusedSpendId = nil
        }) {
            Group {
                if todayDirection == .orderedAscending {
                    Text("← Today")
                } else {
                    Text("Today →")
                }
            }
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}
