//
//  UpcomingWidget.swift
//  UpcomingWidget
//
//  Created by Gabriel Valdivia on 6/18/24.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), events: [])
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, events: [])
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        let events = loadSharedEvents()  // Load events from shared storage
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration, events: events)
            entries.append(entry)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    func loadSharedEvents() -> [Event] {
        let userDefaults = UserDefaults(suiteName: "group.yourAppGroupName")
        if let savedEvents = userDefaults?.object(forKey: "Events") as? Data {
            if let decodedEvents = try? JSONDecoder().decode([Event].self, from: savedEvents) {
                return decodedEvents
            }
        }
        return []
    }
}

struct Event: Codable {
    var date: String
    var name: String
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let events: [Event]
}

struct UpcomingWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            Text("Upcoming")
                .font(.headline)
            ForEach(entry.events.prefix(3), id: \.name) { event in
                HStack {
                    Text(event.date)
                    Text(event.name)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UpcomingWidget: Widget {
    let kind: String = "UpcomingWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            UpcomingWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    UpcomingWidget()
} timeline: {
    let events = [Event(date: "6/19", name: "Meeting"), Event(date: "6/20", name: "Workshop"), Event(date: "6/21", name: "Conference")]
    SimpleEntry(date: .now, configuration: .smiley, events: events)
    SimpleEntry(date: .now, configuration: .starEyes, events: events)
}
