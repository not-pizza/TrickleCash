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
    var foregroundShowingOffset: CGFloat
    var currentTime: Date

    @State private var showingAddBucketSheet = false
    @State private var newBucketName = ""
    @State private var newBucketAmount = ""
    
    enum BucketType {
        case saveUp
        case setAsideForWeekend
        case paymentPlan
    }

    
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
        
        let debtClockHeight = 20.0
        
        return ZStack(alignment: .top) {
            balanceBackgroundGradient(balance, colorScheme: colorScheme).ignoresSafeArea()
            
            let balanceHeight = (Double(foregroundShowingOffset) - 50.0) + (balance < 0 ? 0.0 : debtClockHeight + 10)
            
            VStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Color.clear
                            .frame(width: 24, height: 24)
                        Spacer()
                        
                        VStack(spacing: 10) {
                            CircularBalanceView(appData: appData, currentTime: currentTime, frameSize: balanceHeight)
                            if balance < 0 {
                                if let debtClock = debtClock {
                                    Text("Out of debt \(debtClock)").frame(height: debtClockHeight)
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
                    .frame(height: foregroundShowingOffset, alignment: .top)
                    
                    
                }
                .frame(height: foregroundShowingOffset, alignment: .top)
                
                Spacer().frame(height: 60)
                
                ScrollView {
                    Spacer().frame(height: 1)
                    VStack {
                        Button(action:
                        {
                        }) {
                            HStack {
                                Spacer()
                                Text("Save up Money")
                                Spacer()
                            }
                            .frame(height: 30)
                        }
                        .buttonStyle(AddBucketButtonStyle())
                        
                        Button(action:
                        {
                        }) {
                            HStack {
                                Spacer()
                                Text("Set Aside for the Weekend")
                                Spacer()
                            }
                            .frame(height: 30)
                        }
                        .buttonStyle(AddBucketButtonStyle())
                            
                        Button(action:
                        {
                        }) {
                            HStack {
                                Spacer()
                                Text("Payment plan")
                                Spacer()
                            }
                            .frame(height: 30)
                        }
                        .buttonStyle(AddBucketButtonStyle())
                            
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Text("Existing buckets:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                }
            }

        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct AddBucketButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 50)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 50)
                    .stroke(Color.primary.opacity(configuration.isPressed ? 0.3 : 1), lineWidth: 1)
            )
            .foregroundColor(Color.primary.opacity(configuration.isPressed ? 0.3 : 1))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
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
        foregroundShowingOffset: UIScreen.main.bounds.height / 5,
        currentTime: Date()
    )
}
