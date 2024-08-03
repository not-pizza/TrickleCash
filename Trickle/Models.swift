import Foundation
import WidgetKit

struct AppData: Codable {
    var monthlyRate: Double
    var startDate: Date
    var events: [Event]
    
    func getTrickleBalance(time: Date) -> Double {
        let secondsElapsed = time.timeIntervalSince(startDate)
        let perSecondRate = monthlyRate / (30.416 * 24 * 60 * 60)
        let trickleValue = perSecondRate * secondsElapsed
        let totalDeductions = events.reduce(0) { total, event in
            if case .spend(let spend) = event {
                return total + spend.amount
            }
            return total
        }
        return trickleValue - totalDeductions
    }
}

struct Spend: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var dateAdded: Date = Date()
}

enum Event: Codable, Identifiable {
    case spend(Spend)
    
    var id: UUID {
        switch self {
        case .spend(let spend):
            return spend.id
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

func addSpend(spend: Spend) -> AppData {
    var appData = loadAppData();
    appData.events.append(.spend(spend))
    saveAppData(appData: appData)
    return appData
}

func loadAppData() -> AppData {
    if let defaults = UserDefaults(suiteName: "group.pizza.not.Trickle") {
        if let savedData = defaults.data(forKey: "AppData"),
           let decodedData = try? JSONDecoder().decode(UpdatableAppData.self, from: savedData) {
            return decodedData.appData
        }
    }
    // Return default values
    return AppData(
        monthlyRate: 1000.0,
        startDate: Date(),
        events: []
    )
}

func saveAppData(appData: AppData) {
    if let defaults = UserDefaults(suiteName: "group.pizza.not.Trickle") {
        let updatableAppData = UpdatableAppData.v1(appData)
        if let encoded = try? JSONEncoder().encode(updatableAppData) {
            defaults.set(encoded, forKey: "AppData")
            print("saved app data")
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
    }
    print("couldn't save app data")
}
