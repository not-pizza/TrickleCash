import Foundation
import Oklab
import WidgetKit
import SwiftUI

struct AppData: Codable, Equatable {
    private var monthlyRate: Double
    private var startDate: Date
    var events: [Event]
    
    init(monthlyRate: Double, startDate: Date, events: [Event]) {
        self.monthlyRate = monthlyRate
        self.startDate = startDate
        self.events = events
    }
    
    func getMonthlyRate(asOf date: Date = Date()) -> Double {
        let relevantEvents = events.filter { event in
            if case .setMonthlyRate(let rateEvent) = event, rateEvent.dateAdded <= date {
                return true
            }
            return false
        }.sorted { $0.date > $1.date }
        
        if let mostRecentEvent = relevantEvents.first, case .setMonthlyRate(let rateEvent) = mostRecentEvent {
            return rateEvent.rate
        }
        
        return monthlyRate
    }
    
    func getStartDate(asOf date: Date = Date()) -> Date {
        let relevantEvents = events.filter { event in
            if case .setStartDate(let startDateEvent) = event, startDateEvent.dateAdded <= date {
                return true
            }
            return false
        }.sorted { $0.date > $1.date }
        
        if let mostRecentEvent = relevantEvents.first, case .setStartDate(let startDateEvent) = mostRecentEvent {
            return startDateEvent.startDate
        }
        
        return startDate
    }
    
    func getTrickleBalance(time: Date) -> Double {
        let currentStartDate = getStartDate(asOf: time)
        let currentMonthlyRate = getMonthlyRate(asOf: time)
        let secondsElapsed = time.timeIntervalSince(currentStartDate)
        let perSecondRate = currentMonthlyRate / (30.416 * 24 * 60 * 60)
        let trickleValue = perSecondRate * secondsElapsed
        let totalDeductions = events.reduce(0) { total, event in
            if case .spend(let spend) = event {
                return total + spend.amount
            }
            return total
        }
        return trickleValue - totalDeductions + 0.01
    }

    func getPercentThroughCurrentCent(time: Date) -> Double {
        let balance = getTrickleBalance(time: time)
        var percent = (balance - 0.005).truncatingRemainder(dividingBy: 0.01) * 100
        if balance < 0 {
            percent = 1 + percent
        }
        return percent
    }
    
    func addSpend(spend: Spend) -> Self {
        var events = self.events
        events.append(.spend(spend))
        return Self(monthlyRate: self.monthlyRate, startDate: self.startDate, events: events)
    }
    
    func setMonthlyRate(_ rate: SetMonthlyRate) -> Self {
        var events = self.events
        events.append(.setMonthlyRate(rate))
        return Self(monthlyRate: self.monthlyRate, startDate: self.startDate, events: events)
    }
    
    func setStartDate(_ startDate: SetStartDate) -> Self {
        var events = self.events
        events.append(.setStartDate(startDate))
        return Self(monthlyRate: self.monthlyRate, startDate: self.startDate, events: events)
    }
    
    func deleteEvent(id: UUID) -> Self {
        var events = self.events
        events.removeAll { $0.id == id }
        return Self(monthlyRate: monthlyRate, startDate: startDate, events: events)
    }

    
    
    func save() -> Self {
        if let defaults = UserDefaults(suiteName: "group.pizza.not.Trickle") {
            let updatableAppData = UpdatableAppData.v1(self)
            if let encoded = try? JSONEncoder().encode(updatableAppData) {
                defaults.set(encoded, forKey: "AppData")
                print("saved app data")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        else {
            print("couldn't save app data")
        }
        return self
    }
    
    static func load() -> Self? {
        if let defaults = UserDefaults(suiteName: "group.pizza.not.Trickle") {
            if let savedData = defaults.data(forKey: "AppData"),
               let decodedData = try? JSONDecoder().decode(UpdatableAppData.self, from: savedData) {
                return decodedData.appData
            }
        }
        // Return default values
        return nil
    }
    
    static func loadOrDefault() -> Self {
        if let defaults = UserDefaults(suiteName: "group.pizza.not.Trickle") {
            if let savedData = defaults.data(forKey: "AppData"),
               let decodedData = try? JSONDecoder().decode(UpdatableAppData.self, from: savedData) {
                return decodedData.appData
            }
        }
        // Return default values
        return Self(
            monthlyRate: 1000.0,
            startDate: Date(),
            events: []
        )
    }
}

struct SetMonthlyRate: Codable, Equatable, Identifiable {
    var rate: Double
    var dateAdded: Date = Date()
    var id: UUID = UUID()
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "SetMonthlyRate(rate: $\(String(format: "%.2f", rate)))"
    }
}

struct SetStartDate: Codable, Equatable, Identifiable {
    var startDate: Date
    var dateAdded: Date = Date()
    var id: UUID = UUID()
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "SetStartDate(startDate: \(formatter.string(from: startDate)))"
    }
}

struct Spend: Identifiable, Codable, Equatable {
    enum AddedFrom : Codable, Equatable {
        case shortcut
    }
    
    var id: UUID = UUID()
    var name: String
    var merchant: String?
    var paymentMethod: String?
    var amount: Double
    var dateAdded: Date = Date()
    
    // If unset, it means it was added by the app
    var addedFrom: AddedFrom?
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Spend(amount: $\(String(format: "%.2f", amount)), name: \"$\(name)\""
    }
}

enum Event: Codable, Identifiable, Equatable {
    case spend(Spend)
    case setMonthlyRate(SetMonthlyRate)
    case setStartDate(SetStartDate)
    
    var id: UUID {
        switch self {
        case .spend(let spend):
            return spend.id
        case .setMonthlyRate(let setMonthlyRate):
            return setMonthlyRate.id
        case .setStartDate(let setStartDate):
            return setStartDate.id
        }
    }
    
    var date: Date {
        switch self {
        case .spend(let spend):
            return spend.dateAdded
        case .setMonthlyRate(let event):
            return event.dateAdded
        case .setStartDate(let event):
            return event.dateAdded
        }
    }
    
    var description: String {
        switch self {
        case .spend(let spend):
            return spend.description
        case .setMonthlyRate(let event):
            return event.description
        case .setStartDate(let event):
            return event.description
        }
    }
}

enum UpdatableAppData: Codable {
    case v1(AppData)
    
    var appData: AppData {
        switch self {
        case .v1(let data):
            return data
        }
    }
}


func formatCurrencyNoDecimals(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
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
