//
//  TrickleBackground.swift
//  Trickle
//
//  Created by Andre Popovitch on 8/7/24.
//

import Foundation
import SwiftUI

struct BackgroundView: View {
    @Binding var appData: AppData
    var onSettingsTapped: () -> Void
    var forgroundShowingOffset: CGFloat
    var currentTime: Date
    
    @Environment(\.colorScheme) var colorScheme
    
    var formatStyle: Date.RelativeFormatStyle {
        var formatStyle = Date.RelativeFormatStyle()
        formatStyle.presentation = .named
        return formatStyle
    }
    
    var body: some View {
        let balance = appData.getTrickleBalance(asOf: currentTime)
        let perSecondRate = appData.getDailyRate(asOf: currentTime) / 24 / 60 / 60
        
        let timeAtZero = Calendar.current.date(byAdding: .second, value: Int(-balance / perSecondRate), to: currentTime)
        if timeAtZero == nil {
            print("Time at zero was nil")
        }
        let debtClock = timeAtZero?.formatted(formatStyle)
        if debtClock == nil {
            print("debt clock was nil")
        }
        
        return ZStack {
            balanceBackgroundGradient(balance, colorScheme: colorScheme).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Color.clear
                        .frame(width: 24, height: 24)  // Dummy element
                    Spacer()
                    
                    VStack(spacing: 10) {
                        CircularBalanceView(appData: appData, currentTime: currentTime, frameSize: forgroundShowingOffset * 0.7)
                        if balance < 0 {
                            if let debtClock = debtClock {
                                Text("Out of debt \(debtClock)")
                            }
                            else {
                                Text("Error with debt clock, \(-balance / perSecondRate / 60 / 60 / 24)")
                            }
                        }
                    }
                    
                    
                    Spacer()
                    NavigationLink(
                        destination: SettingsView(
                            appData: $appData
                        )) {
                        Image(systemName: "gear")
                            .foregroundColor(.primary)
                            .font(.system(size: 26))
                    }

                }
                .padding()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    BackgroundView(
        appData: .constant(AppData(
            monthlyRate: 1000,
            startDate: Date().startOfDay,
            events: [
                .spend(Spend(name: "7/11", amount: 30))
            ]
        )),
        onSettingsTapped: {},
        forgroundShowingOffset: UIScreen.main.bounds.height / 5,
        currentTime: Date()
    )
}
