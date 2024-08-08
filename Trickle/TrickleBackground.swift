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
    
    var body: some View {
        let balance = appData.getTrickleBalance(time: currentTime)
        
        ZStack {
            balanceBackgroundGradient(balance, colorScheme: colorScheme).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Color.clear
                        .frame(width: 24, height: 24)  // Dummy element
                    Spacer()
                    
                    CircularBalanceView(appData: appData, currentTime: currentTime, frameSize: forgroundShowingOffset * 0.8)
                    
                    
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
