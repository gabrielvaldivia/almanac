//
//  NotificationsView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/13/24.
//

import Foundation
import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @State private var notifications: [UNNotificationRequest] = []
    @EnvironmentObject var appData: AppData

    var body: some View {
        List(notifications, id: \.identifier) { notification in
            VStack(alignment: .leading) {
                Text(notification.content.title)
                    .font(.headline)
                if let trigger = notification.trigger as? UNCalendarNotificationTrigger,
                   let nextTriggerDate = trigger.nextTriggerDate() {
                    Text("Scheduled for: \(nextTriggerDate, formatter: dateFormatter)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                if let eventId = notification.content.userInfo["eventId"] as? String,
                   let event = appData.events.first(where: { $0.id.uuidString == eventId }) {
                    Text("Event: \(event.title)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Notifications")
        .onAppear(perform: loadNotifications)
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
                    return false
                }
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()