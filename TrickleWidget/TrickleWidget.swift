import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), value: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let appData = AppData.loadOrDefault()
        let entry = SimpleEntry(date: Date(), value: appData.getTrickleBalance(time: Date()))
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        let endDate = Calendar.current.date(byAdding: .minute, value: 24, to: currentDate)!

        var nextUpdateDate = currentDate
        let appData = AppData.loadOrDefault()
        while nextUpdateDate <= endDate {
            let entry = SimpleEntry(date: nextUpdateDate, value: appData.getTrickleBalance(time: Date()))
            entries.append(entry)
            nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: nextUpdateDate)!
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
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
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let background = balanceBackgroundGradient(entry.value, colorScheme: colorScheme).ignoresSafeArea()
        
        return ZStack {
            VStack {
                Text("Trickle")
                viewBalanceNoDecimals(entry.value)
            }
        }
        .widgetBackground(backgroundView: background)
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
        TrickleWidgetEntryView(entry: SimpleEntry(date: Date(), value: 20))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}

