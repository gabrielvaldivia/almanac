import Foundation
import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @State private var notifications: [UNNotificationRequest] = []
    @EnvironmentObject var appData: AppData
    @State private var groupedEvents: [(key: Date, value: [Event])] = []

    var body: some View {
        VStack {
            List {
                ForEach(groupedEvents, id: \.key) { date, events in
                    Section(header: Text("\(date, formatter: dateFormatter)")) {
                        ForEach(events, id: \.id) { event in
                            Text(event.title)
                                .font(.headline)
                        }
                        .onDelete { indexSet in
                            deleteNotification(at: indexSet, for: date)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarItems(trailing: Button(action: {
                loadNotifications()
                groupedEvents = eventsGroupedByDate()
            }) {
                Image(systemName: "arrow.clockwise")
            })
            .onAppear {
                loadNotifications()
                groupedEvents = eventsGroupedByDate()
            }
            .onReceive(appData.$events) { _ in
                loadNotifications()
                groupedEvents = eventsGroupedByDate()
            }
        }
    }

    private func loadNotifications() {
        let now = Date()
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: now)!

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                self.notifications = requests.filter { request in
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                       let triggerDate = trigger.nextTriggerDate() {
                        return triggerDate <= oneYearFromNow
                    }
                    // Include the daily notification by its identifier
                    return request.identifier == "dailyNotification"
                }
                groupedEvents = eventsGroupedByDate() // Update groupedEvents after loading notifications
            }
        }
    }

    private func eventsGroupedByDate() -> [(key: Date, value: [Event])] {
        let calendar = Calendar.current
        let groupedEvents = Dictionary(grouping: appData.events.filter { $0.notificationsEnabled }) { event -> Date in
            return calendar.startOfDay(for: event.date)
        }
        return groupedEvents.filter { !$0.value.isEmpty }.sorted { $0.key < $1.key }
    }

    private func deleteNotification(at indexSet: IndexSet, for date: Date) {
        for index in indexSet {
            let event = groupedEvents.first { $0.key == date }?.value[index]
            if let event = event {
                // Remove the notification request from UNUserNotificationCenter
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [event.id.uuidString])
                // Update the notifications state
                notifications.removeAll { $0.identifier == event.id.uuidString }
                // Update the event's notificationsEnabled property
                if let eventIndex = appData.events.firstIndex(where: { $0.id == event.id }) {
                    appData.events[eventIndex].notificationsEnabled = false
                    appData.objectWillChange.send() // Notify the view of changes
                    appData.saveEvents() // Save the updated events
                }
            }
        }
        groupedEvents = eventsGroupedByDate() // Update groupedEvents after deletion
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .none
    return formatter
}()