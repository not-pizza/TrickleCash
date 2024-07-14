import Foundation

struct AppData: Codable {
    var monthlyRate: Double
    var startDate: Date
    var events: [Event]
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
