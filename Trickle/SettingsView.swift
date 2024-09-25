import Foundation
import SwiftUI

struct SettingsView: View {
    @Binding var appData: AppData
    @State private var tempMonthlyRate: String
    @FocusState private var focusedField: Bool
    @State private var showUndoButton: Bool = false
    @State private var previousStartDate: Date?
    
    init(appData: Binding<AppData>) {
        _appData = appData
        tempMonthlyRate = String(format: "%.2f", appData.wrappedValue.getMonthlyRate())
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Start Date")
                            .font(.headline)
                        Text("Current start date: \(formattedDate(appData.getStartDate()))")
                            .font(.subheadline)
                        
                        if !showUndoButton {
                            Button("Restart from today") {
                                previousStartDate = appData.getStartDate()
                                appData = appData.setStartDate(SetStartDate(startDate: Date().startOfDay))
                                showUndoButton = true
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if showUndoButton {
                            Button("Undo restart") {
                                if let previousDate = previousStartDate {
                                    appData = appData.setStartDate(SetStartDate(startDate: previousDate))
                                    showUndoButton = false
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Monthly Spending")
                            .font(.headline)
                        Text("Excluding bills and subscriptions")
                            .font(.subheadline)
                        TextField("Enter amount", text: $tempMonthlyRate)
                            .keyboardType(.decimalPad)
                            .focused($focusedField)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: tempMonthlyRate) { newTempMonthlyRate in
                                if let monthlyRate = toDouble(newTempMonthlyRate) {
                                    appData = appData
                                        .setMonthlyRate(SetMonthlyRate(rate: monthlyRate ))
                                }
                            }
                    }
                    
                }
                .padding()

                SpendingAvailability(monthlyRate: appData.getMonthlyRate())

                Spacer()
            }
        }
        .navigationTitle("Settings")
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
