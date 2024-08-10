//
//  CircularBalanceView.swift
//  Trickle
//
//  Created by Andre Popovitch on 8/7/24.
//

import Foundation
import SwiftUI

public struct CircularBalanceView: View {
    var appData: AppData
    var currentTime: Date
    let frameSize: Double
    
    @Environment(\.colorScheme) var colorScheme
    
    var backgroundColor: Color {
        colorScheme == .dark ?
            Color.white :
            Color.black
    }
    
    public var body: some View {
        let balance = appData.getTrickleBalance(asOf: currentTime)
        let progress = appData.getPercentThroughCurrentCent(time: currentTime)

        
        let lineWidth: CGFloat = 8
        return ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.3)
                .foregroundColor(backgroundColor)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(backgroundColor)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            VStack {
                viewBalance(balance)
                    .frame(width: frameSize * 0.8)
                    .scaledToFill()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }.frame(width: frameSize, height: frameSize)
    }
}
