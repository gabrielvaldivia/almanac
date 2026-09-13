import SwiftUI

struct PastEventsView: View {
    @EnvironmentObject var appData: AppData
    var category: String?
    @State private var selectedEvent: Event?

    private var groups: [Date: [Event]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return Dictionary(grouping: appData.events.filter {
            ($0.endDate ?? $0.date) < today && (category == nil || $0.category == category)
        }) { calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date))! }
    }

    var body: some View {
        List {
            if groups.isEmpty { Text("No past events").foregroundStyle(.secondary) }
            ForEach(groups.keys.sorted(by: >), id: \.self) { month in
                let events = groups[month]!.sorted { $0.date > $1.date }
                Section(month.formatted(.dateTime.month(.wide).year())) {
                    ForEach(events) { event in
                        Button { selectedEvent = event } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title).foregroundStyle(.primary)
                                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = Set(offsets.map { events[$0].id })
                        appData.events.removeAll { ids.contains($0.id) }
                        appData.saveEvents()
                    }
                }
            }
        }
        .navigationTitle("Past Events")
        .sheet(item: $selectedEvent) { _ in
            EditEventView(events: $appData.events, selectedEvent: $selectedEvent,
                          showEditSheet: Binding(get: { selectedEvent != nil }, set: { if !$0 { selectedEvent = nil } }),
                          saveEvents: appData.saveEvents)
        }
    }
}
