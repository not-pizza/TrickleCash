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
        let progress = min(appData.getPercentThroughCurrentCent(time: currentTime), 1.0)
        
        let lineWidth: CGFloat = 8
        return ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: backgroundColor, location: 0),
                            .init(color: backgroundColor, location: max(progress-0.001, 0)),
                            .init(color: backgroundColor.opacity(0.3), location: progress),
                            .init(color: backgroundColor.opacity(0.3), location: 1)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
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
