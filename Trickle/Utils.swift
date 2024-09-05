//
//  Utils.swift
//  Trickle
//
//  Created by Andre Popovitch on 8/11/24.
//

import Foundation
import SwiftUI
import Oklab
let secondsPerMonth: Double = (365.0 / 12.0) * 60.0 * 60.0 * 24.0
let secondsPerDay: Double = 24 * 60 * 60
let secondsPerWeek: Double = secondsPerDay * 7

func formatCurrencyNoDecimals(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "$0"
}

func formatCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    if amount > 9999 || amount < -999 {
        formatter.maximumFractionDigits = 0
    }
    return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
}

func viewBalance(_ amount: String) -> some View {
    return Text(amount)
            .font(.title2)
            .monospacedDigit()
            .bold()
            .lineLimit(1)
}

func viewBalanceNoDecimals(_ amount: Double) -> some View {
    viewBalance(formatCurrencyNoDecimals(amount))
}

func viewBalance(_ amount: Double) -> some View {
    viewBalance(formatCurrency(amount))
}

func balanceBackground(_ amount: Double, colorScheme: ColorScheme) -> Color {
    amount < 0 ? Color.red : Color.green
}

func balanceBackgroundGradient(_ amount: Double, colorScheme: ColorScheme, boost: Float = 0) -> LinearGradient {
    let lightness_delta: Float = colorScheme == .dark ? -(0.07 + boost) : (0.1 + boost)
    
    let grayify: Float = amount < 1 && amount > -1 ? 0.2 : 1
    
    let reds = [
        OklabColorPolar(
            lightness: 0.65 + lightness_delta,
            chroma: 0.2017 * grayify,
            hueDegrees: 26.33
        ),
        OklabColorPolar(
            lightness: 0.65 + lightness_delta,
            chroma: 0.2017 * grayify,
            hueDegrees: 316.44
        )
    ]
    
    let greens = [
        OklabColorPolar(
            lightness: 0.65 + lightness_delta,
            chroma: 0.1678 * grayify,
            hueDegrees: 132.12
        ),
        OklabColorPolar(
            lightness: 0.65 + lightness_delta,
            chroma: 0.1678 * grayify,
            hueDegrees: 226.51
        )
    ]
    
    let colors = (amount > 0 ? greens : reds).map({color in Color(color)})
    
    return LinearGradient(gradient: Gradient(colors: colors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
}
