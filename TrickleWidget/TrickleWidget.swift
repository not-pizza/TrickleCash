import WidgetKit
import SwiftUI

enum UpdatableAppData: Codable {
    case v1(AppData)
    
    var appData: AppData {
        switch self {
        case .v1(let data):
            return data
        }
    }
}

struct AppData: Codable {
    var monthlyRate: Double
    var startDate: Date
    var events: [Event]
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

struct Spend: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var dateAdded: Date = Date()
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), value: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), value: calculateValue(time: Date()))
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        let endDate = Calendar.current.date(byAdding: .minute, value: 24, to: currentDate)! // Updates for the next 24 hours

        var nextUpdateDate = currentDate
        while nextUpdateDate <= endDate {
            let entry = SimpleEntry(date: nextUpdateDate, value: calculateValue(time: nextUpdateDate))
            entries.append(entry)
            nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: nextUpdateDate)!
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func calculateValue(time: Date) -> Double {
        let appData = loadAppData()
        let secondsElapsed = time.timeIntervalSince(appData.startDate)
        let perSecondRate = appData.monthlyRate / (30.416 * 24 * 60 * 60)
        let trickleValue = perSecondRate * secondsElapsed
        let totalDeductions = appData.events.reduce(0) { total, event in
            if case .spend(let spend) = event {
                return total + spend.amount
            }
            return total
        }
        return trickleValue - totalDeductions
    }
    
    private func loadAppData() -> AppData {
        if let defaults = UserDefaults(suiteName: "group.pizza.not.Trickle") {
            if let savedData = defaults.data(forKey: "AppData"),
               let decodedData = try? JSONDecoder().decode(UpdatableAppData.self, from: savedData) {
                return decodedData.appData
            } else {
                // Return default values
                return AppData(
                    monthlyRate: 1000.0,
                    startDate: Date(),
                    events: []
                )
            }
        }
        return AppData(
            monthlyRate: 1000.0,
            startDate: Date(),
            events: []
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let value: Double
}

extension View {
    func widgetBackground(backgroundView: some View) -> some View {
        if #available(watchOS 10.0, iOSApplicationExtension 17.0, iOS 17.0, macOSApplicationExtension 14.0, *) {
            return containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            return background(backgroundView)
        }
    }
}

struct TrickleWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("Current Balance")
            Text("$\(entry.value, specifier: "%.0f")")
                .font(.largeTitle)
                .monospacedDigit()
        }
        .widgetBackground(backgroundView: Color.clear)
    }
}

struct TrickleWidget: Widget {
    let kind: String = "TrickleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TrickleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cash Balance")
        .description("Shows your current cash balance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TrickleWidget_Previews: PreviewProvider {
    static var previews: some View {
        TrickleWidgetEntryView(entry: SimpleEntry(date: Date(), value: 1234.56))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
