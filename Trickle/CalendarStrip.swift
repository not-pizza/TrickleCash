//
//  CalendarStrip.swift
//  Trickle
//
//  Created by Andre Popovitch on 8/3/24.
//

import Foundation
import SwiftUI

struct CalendarStrip: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    
    @State private var showDatePicker = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate)!
                    onDateSelected(selectedDate)
                }) {
                    Image(systemName: "chevron.left")
                }.buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    showDatePicker.toggle()
                }) {
                    Text("\(dateFormatter.string(from: selectedDate))")
                        .font(.headline)
                }.buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate)!
                    onDateSelected(selectedDate)
                }) {
                    Image(systemName: "chevron.right")
                }.buttonStyle(.plain)
            }
            .padding()
            
            if showDatePicker {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .onChange(of: selectedDate) { newValue in
                        onDateSelected(newValue)
                        showDatePicker = false
                    }
                    .padding()
            }
        }
    }
}
