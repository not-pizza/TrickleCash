//
//  SettingsView.swift
//  Trickle
//
//  Created by Andre Popovitch on 8/7/24.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @Binding var appData: AppData
    @State private var tempMonthlyRate: String
    @FocusState private var focusedField: Bool
    
    
    init(appData: Binding<AppData>) {
        _appData = appData
        tempMonthlyRate = String(format: "%.2f", appData.wrappedValue.getMonthlyRate())
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Monthly Spending")
                            .font(.headline)
                        Text("Excluding bills and subscriptions")
                            .font(.subheadline)
                        TextField("Enter amount", text: $tempMonthlyRate)
                            .inputView(
                                CalculatorKeyboard.self,
                                text: $tempMonthlyRate,
                                onSubmit: {
                                    focusedField = false
                                }
                            )
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
                                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Start Date")
                            .font(.headline)
                        DatePicker("", selection: Binding(
                            get: { appData.getStartDate() },
                            set: { startDate in
                                appData = appData.setStartDate(SetStartDate(startDate: startDate))
                            }
                        ), displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()

                SpendingAvailability(monthlyRate: appData.getMonthlyRate())

                Spacer()
            }
        }
        .navigationTitle("Settings")
    }
}
