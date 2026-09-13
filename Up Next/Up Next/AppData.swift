//
//  AppData.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import StoreKit
import SwiftUI
import UserNotifications
import WidgetKit

// Model for an event
struct Event: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date: Date { didSet { calendarDay = CalendarDay(date) } }
    var endDate: Date? { didSet { calendarEndDay = endDate.map { CalendarDay($0) } } }
    var calendarDay: CalendarDay?
    var calendarEndDay: CalendarDay?
    var calendarSchemaVersion = 1
    var color: CodableColor
    var category: String?
    var notificationsEnabled: Bool = true
    var repeatOption: RepeatOption = .never
    var repeatUntil: Date?
    var seriesID: UUID?
    var customRepeatCount: Int?
    var repeatUnit: String?
    var repeatUntilCount: Int?  // Added this line
    var useCustomRepeatOptions: Bool = false
    var recurrence: RecurrenceRule?
    var occurrenceIndex: Int?
    var isRecurrenceException = false

    // Initializer for Event
    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        endDate: Date? = nil,
        color: CodableColor,
        category: String? = nil,
        notificationsEnabled: Bool = true,
        repeatOption: RepeatOption = .never,
        repeatUntil: Date? = nil,
        seriesID: UUID? = nil,
        customRepeatCount: Int? = nil,
        repeatUnit: String? = nil,
        repeatUntilCount: Int? = nil,
        useCustomRepeatOptions: Bool = false
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.endDate = endDate
        self.calendarDay = CalendarDay(date)
        self.calendarEndDay = endDate.map { CalendarDay($0) }
        self.color = color
        self.category = category
        self.notificationsEnabled = notificationsEnabled
        self.repeatOption = repeatOption
        self.repeatUntil = repeatUntil
        self.seriesID = repeatOption == .never ? nil : seriesID
        self.customRepeatCount = customRepeatCount
        self.repeatUnit = repeatUnit
        self.repeatUntilCount = repeatUntilCount
        self.useCustomRepeatOptions = useCustomRepeatOptions
        print("Event initialized: \(self)")
    }

    // Custom decoding to provide default values for new properties
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        let calendar = decoder.userInfo[.eventCalendar] as? Calendar ?? .current
        let legacyDate = try container.decode(Date.self, forKey: .date)
        let legacyEnd = try container.decodeIfPresent(Date.self, forKey: .endDate)
        calendarDay = try container.decodeIfPresent(CalendarDay.self, forKey: .calendarDay) ?? CalendarDay(legacyDate, calendar: calendar)
        calendarEndDay = try container.decodeIfPresent(CalendarDay.self, forKey: .calendarEndDay) ?? legacyEnd.map { CalendarDay($0, calendar: calendar) }
        guard let resolved = calendarDay?.date(in: calendar) else {
            throw DecodingError.dataCorruptedError(forKey: .calendarDay, in: container, debugDescription: "Invalid calendar date")
        }
        date = resolved
        endDate = calendarEndDay?.date(in: calendar)
        if calendarEndDay != nil && endDate == nil {
            throw DecodingError.dataCorruptedError(forKey: .calendarEndDay, in: container, debugDescription: "Invalid end calendar date")
        }
        calendarSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .calendarSchemaVersion) ?? 0
        color = try container.decode(CodableColor.self, forKey: .color)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        repeatOption = try container.decodeIfPresent(RepeatOption.self, forKey: .repeatOption) ?? .never
        repeatUntil = try container.decodeIfPresent(Date.self, forKey: .repeatUntil)
        seriesID = try container.decodeIfPresent(UUID.self, forKey: .seriesID)
        customRepeatCount = try container.decodeIfPresent(Int.self, forKey: .customRepeatCount) ?? 1  // Default value
        repeatUnit = try container.decodeIfPresent(String.self, forKey: .repeatUnit) ?? "Days"  // Default value
        repeatUntilCount = try container.decodeIfPresent(Int.self, forKey: .repeatUntilCount) ?? 1  // Default value
        useCustomRepeatOptions = try container.decodeIfPresent(Bool.self, forKey: .useCustomRepeatOptions) ?? false
        recurrence = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrence)
        occurrenceIndex = try container.decodeIfPresent(Int.self, forKey: .occurrenceIndex)
        isRecurrenceException = try container.decodeIfPresent(Bool.self, forKey: .isRecurrenceException) ?? false
    }

    // Coding keys for encoding and decoding
    enum CodingKeys: String, CodingKey {
        case id, title, date, endDate, color, category, notificationsEnabled, repeatOption,
            repeatUntil, seriesID, customRepeatCount, repeatUnit, repeatUntilCount,
            useCustomRepeatOptions, recurrence, occurrenceIndex, isRecurrenceException, calendarDay, calendarEndDay, calendarSchemaVersion
    }

    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id
    }
}

// A missing series ID must never match unrelated standalone events.
enum CategoryName {
    static func isValid(_ name: String, existing: [String], excluding original: String? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !existing.contains {
            $0 != original && $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
    }
}

enum EventSeries {
    static func members(of event: Event, in events: [Event]) -> [Event] {
        guard let seriesID = event.seriesID else { return [] }
        return events.filter { $0.seriesID == seriesID }
    }

    static func updating(_ selected: Event, with replacement: Event, in events: [Event], calendar: Calendar = .current) -> [Event] {
        if selected.recurrence != nil { return Recurrence.updatingSeries(selected, with: replacement, in: events, calendar: calendar) }
        return updatingLegacy(selected, with: replacement, in: events, calendar: calendar)
    }

    static func updatingLegacy(_ selected: Event, with replacement: Event, in events: [Event],
                         calendar: Calendar = .current) -> [Event] {
        guard let seriesID = selected.seriesID else { return events }
        let members = self.members(of: selected, in: events).sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }
        guard let anchor = members.firstIndex(where: { $0.id == selected.id }) else { return events }
        if replacement.repeatOption == .never {
            var single = replacement
            single.seriesID = nil
            return events.compactMap { event in
                event.id == selected.id ? single : (event.seriesID == seriesID ? nil : event)
            }
        }
        let sameInterval = selected.repeatOption == replacement.repeatOption
            && selected.customRepeatCount == replacement.customRepeatCount
            && selected.repeatUnit == replacement.repeatUnit
        let shift = calendar.dateComponents([.day], from: calendar.startOfDay(for: selected.date),
                                             to: calendar.startOfDay(for: replacement.date)).day ?? 0
        let duration = replacement.endDate.map {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: replacement.date),
                                    to: calendar.startOfDay(for: $0)).day ?? 0
        }
        let component: Calendar.Component
        let interval: Int
        switch replacement.repeatOption {
        case .daily: component = .day; interval = 1
        case .weekly: component = .weekOfYear; interval = 1
        case .monthly: component = .month; interval = 1
        case .yearly: component = .year; interval = 1
        case .custom:
            interval = max(1, replacement.customRepeatCount ?? 1)
            switch replacement.repeatUnit?.lowercased() {
            case "weeks": component = .weekOfYear
            case "months": component = .month
            case "years": component = .year
            default: component = .day
            }
        case .never: return events
        }
        var updates: [UUID: Event] = [:]
        for (index, event) in members.enumerated() {
            var updated = replacement
            updated.id = event.id
            updated.seriesID = seriesID
            updated.date = sameInterval
                ? calendar.date(byAdding: .day, value: shift, to: event.date) ?? event.date
                : calendar.date(byAdding: component, value: (index - anchor) * interval,
                                to: replacement.date) ?? event.date
            updated.endDate = duration.flatMap { calendar.date(byAdding: .day, value: $0, to: updated.date) }
            updates[event.id] = updated
        }
        return events.map { updates[$0.id] ?? $0 }
    }

    static func removing(_ event: Event, from events: [Event]) -> [Event] {
        guard let seriesID = event.seriesID else { return events }
        return events.filter { $0.seriesID != seriesID }
    }
}

// Enum for repeat options
enum RepeatOption: String, Codable, CaseIterable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"
}

// Enum for repeat until options
enum RepeatUntilOption: String, Codable {
    case indefinitely = "Indefinitely"
    case after = "After"
    case onDate = "On Date"
}

// Model for category data
struct CategoryData: Codable {
    let name: String
    let color: CodableColor
    let repeatOption: RepeatOption
    let showRepeatOptions: Bool
    let customRepeatCount: Int
    let repeatUnit: String
    let repeatUntilOption: RepeatUntilOption
    let repeatUntilCount: Int
    let repeatUntil: Date
}

// Model for a color that can be encoded and decoded
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    // Initializer for CodableColor
    init(color: Color) {
        if let components = UIColor(color).cgColor.components {
            self.red = Double(components[0])
            self.green = Double(components[1])
            self.blue = Double(components[2])
            self.opacity = Double(components[3])
        } else {
            self.red = 0
            self.green = 0
            self.blue = 0
            self.opacity = 1
        }
    }

    // Custom decoding for CodableColor
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        opacity = try container.decode(Double.self, forKey: .opacity)
    }

    // Custom encoding for CodableColor
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(opacity, forKey: .opacity)
    }

    // Coding keys for encoding and decoding
    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }
}

// Main class for managing app data
class AppData: NSObject, ObservableObject {
    static let shared = AppData()  // Singleton instance

    @Published var events: [Event] = []
    @Published var categories:
        [(
            name: String, color: Color, repeatOption: RepeatOption, customRepeatCount: Int,
            repeatUnit: String, repeatUntilOption: RepeatUntilOption, repeatUntilCount: Int,
            repeatUntil: Date
        )] = [
            ("Work", .blue, .never, 1, "Days", .indefinitely, 1, Date()),
            ("Social", .green, .never, 1, "Days", .indefinitely, 1, Date()),
            ("Birthdays", .red, .yearly, 1, "Years", .indefinitely, 1, Date()),
            ("Holidays", .purple, .yearly, 1, "Years", .indefinitely, 1, Date()),
        ]
    {
        didSet {
            if isDataLoaded {
                saveCategories()
            }
        }
    }
    @Published var defaultCategory: String = "" {
        didSet {
            if isDataLoaded {
                AppPreferences.shared.set(defaultCategory, forKey: "defaultCategory")
            }
        }
    }
    @Published var notificationTime: Date =
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    {
        didSet {
            if isDataLoaded {
                AppPreferences.saveReminderTime(notificationTime)
                saveState()
                scheduleDailyNotification()
            }
        }
    }
    @Published var dailyNotificationEnabled: Bool = AppPreferences.shared.bool(
        forKey: "dailyNotificationEnabled")
    {
        didSet {
            if isDataLoaded {
                AppPreferences.shared.set(
                    dailyNotificationEnabled, forKey: "dailyNotificationEnabled")
                scheduleDailyNotification()
            }
        }
    }
    @Published var eventStyle: String = AppPreferences.shared.string(forKey: "eventStyle") ?? "flat"
    {
        didSet {
            if isDataLoaded {
                AppPreferences.shared.set(eventStyle, forKey: "eventStyle")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    @Published var isSubscribed = false

    private var isDataLoaded = false

    @Published private(set) var subscriptionProduct: Product?
    @Published var subscriptionMessage: String?
    @Published var isLoadingSubscription = false
    @Published var isPurchasing = false
    private var transactionListener: Task<Void, Never>?

    var subscriptionPrice: String? {
        guard let product = subscriptionProduct else { return nil }
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: return product.displayPrice
        }
        return "\(product.displayPrice) / \(period.value == 1 ? unit : "\(period.value) \(unit)s")"
    }

    // Computed property for default category color
    var defaultCategoryColor: Color {
        if let category = categories.first(where: { $0.name == defaultCategory }) {
            return category.color
        }
        return .blue
    }

    // Initializer for AppData
    override init() {
        super.init()
        migrateUserDefaults()  // Call the migration function
        loadCategories()
        defaultCategory = AppPreferences.shared.string(forKey: "defaultCategory") ?? ""
        dailyNotificationEnabled = AppPreferences.shared.bool(forKey: "dailyNotificationEnabled")
        eventStyle = AppPreferences.shared.string(forKey: "eventStyle") ?? "flat"
        notificationTime = AppPreferences.reminderTime()
        loadEvents()
        isDataLoaded = true
        UNUserNotificationCenter.current().delegate = self
        loadSubscriptionProduct()
    }

    // Function to save categories to UserDefaults
    func saveCategories() {
        let categoryData = categories.map {
            CategoryData(
                name: $0.name, color: CodableColor(color: $0.color), repeatOption: $0.repeatOption,
                showRepeatOptions: false, customRepeatCount: $0.customRepeatCount,
                repeatUnit: $0.repeatUnit, repeatUntilOption: $0.repeatUntilOption,
                repeatUntilCount: $0.repeatUntilCount, repeatUntil: $0.repeatUntil)
        }
        encodeToUserDefaults(
            categoryData, forKey: "categories", suiteName: "group.UpNextIdentifier")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Function to load categories from UserDefaults
    func loadCategories() {
        if let decoded: [CategoryData] = decodeFromUserDefaults(
            [CategoryData].self, forKey: "categories", suiteName: "group.UpNextIdentifier")
        {
            self.categories = decoded.map { categoryData in
                return (
                    name: categoryData.name, color: categoryData.color.color,
                    repeatOption: categoryData.repeatOption,
                    customRepeatCount: categoryData.customRepeatCount,
                    repeatUnit: categoryData.repeatUnit,
                    repeatUntilOption: categoryData.repeatUntilOption,
                    repeatUntilCount: categoryData.repeatUntilCount,
                    repeatUntil: categoryData.repeatUntil
                )
            }
        } else {
            self.categories = [
                ("Work", .blue, .never, 1, "Days", .indefinitely, 1, Date()),
                ("Social", .green, .never, 1, "Days", .indefinitely, 1, Date()),
                ("Birthdays", .red, .yearly, 1, "Years", .indefinitely, 1, Date()),
                ("Holidays", .purple, .yearly, 1, "Years", .indefinitely, 1, Date()),
            ]
        }

        notificationTime = AppPreferences.reminderTime()
    }

    // Function to filter events based on selected category
    func filteredEvents(selectedCategoryFilter: String?) -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        var allEvents = [Event]()

        for event in events {
            if let filter = selectedCategoryFilter {
                if event.category == filter
                    && (event.date >= startOfToday
                        || (event.endDate != nil && event.endDate! >= startOfToday))
                {
                    allEvents.append(event)
                }
            } else {
                if event.date >= startOfToday
                    || (event.endDate != nil && event.endDate! >= startOfToday)
                {
                    allEvents.append(event)
                }
            }
        }

        return allEvents.sorted { $0.date < $1.date }
    }

    @Published var storageError: String?
    private let eventStore = EventStore()

    func loadEvents() {
        notificationTime = AppPreferences.reminderTime()
        do {
            let loaded = try eventStore.load()
            events = Recurrence.replenishing(loaded).map { event in
                var updated = event; updated.calendarSchemaVersion = 1; return updated
            }
            if events.count != loaded.count || loaded.contains(where: { $0.calendarSchemaVersion == 0 || ($0.seriesID != nil && $0.recurrence == nil) }) {
                try eventStore.save(events)
            }
            storageError = nil
        } catch {
            storageError = "Your saved events could not be read. The original data is preserved and saving is paused. \(error.localizedDescription)"
        }
    }

    func restoreEventBackup() {
        do {
            events = try eventStore.restoreBackup()
            storageError = nil
            WidgetCenter.shared.reloadAllTimelines()
            scheduleDailyNotification()
        } catch { storageError = error.localizedDescription }
    }

    func saveEvents() {
        guard storageError == nil else { return }
        do {
            try eventStore.save(events)
            WidgetCenter.shared.reloadAllTimelines()
            scheduleDailyNotification()
        } catch { storageError = "Could not save events: \(error.localizedDescription)" }
    }

    @Published var notificationStatus: String?
    private var notificationTask: Task<Void, Never>?

    func setDailyNotification(enabled: Bool) {
        dailyNotificationEnabled = enabled
        guard enabled else { return }
        Task { @MainActor in
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                if !granted { notificationStatus = "Notifications are blocked. Enable them in iOS Settings." }
                scheduleDailyNotification()
            } catch { notificationStatus = error.localizedDescription }
        }
    }

    func scheduleDailyNotification() {
        let enabled = dailyNotificationEnabled
        let snapshot = events
        let time = AppPreferences.reminderComponents()
        let previous = notificationTask
        notificationTask = Task { @MainActor in
            await previous?.value
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            let plan = enabled && allowed ? NotificationPlan.make(events: snapshot, hour: time.hour ?? 8, minute: time.minute ?? 0) : []
            let error = await NotificationScheduler.shared.replace(with: plan)
            if let error { notificationStatus = "Could not schedule reminders: \(error)" }
            else if enabled && !allowed { notificationStatus = "Notifications are blocked. Enable them in iOS Settings." }
            else if enabled, let last = plan.last {
                notificationStatus = "Reminders scheduled through \(last.date.formatted(date: .abbreviated, time: .omitted)). Open Almanac periodically to keep reminders current."
            } else { notificationStatus = enabled ? "No upcoming reminders to schedule." : nil }
        }
    }

    func waitForNotifications() async { await notificationTask?.value }

    // Function to get today's events
    func getTodayEvents() -> [Event] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let todayEvents = events.filter { event in
            let eventStartOfDay = calendar.startOfDay(for: event.date)
            return eventStartOfDay >= today && eventStartOfDay < tomorrow
        }

        return todayEvents
    }

    // Function to save state to UserDefaults
    func saveState() {
        AppPreferences.saveReminderTime(notificationTime)
    }

    // Function to remove notification for an event
    func removeNotification(for event: Event) {
        let center = UNUserNotificationCenter.current()
        let identifier = event.id.uuidString
        print("Removing notification for event ID: \(identifier)")
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // Function to add a new event
    func addEvent(_ event: Event) {
        events.append(event)
        saveEvents()
    }

    // Function to edit an existing event
    func editEvent(_ event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            saveEvents()
        }
    }

    // Function to update event colors when a category color is changed
    func updateEventColors(forCategory category: String, from oldColor: Color, to newColor: Color) {
        for index in events.indices {
            if events[index].category == category {
                events[index].color = CodableColor(color: newColor)
            }
        }
        saveEvents()
    }

    // Function to update events when a category is edited
    func updateEventsForCategoryChange(oldName: String, newName: String, newColor: Color) {
        if defaultCategory == oldName { defaultCategory = newName }
        var eventsUpdated = false
        print("Total events: \(events.count)")
        print("Searching for events with category: \(oldName)")
        for i in 0..<events.count {
            print(
                "Event \(i): title = \(events[i].title), category = \(events[i].category ?? "nil")")
            if events[i].category == oldName {
                events[i].category = newName
                events[i].color = CodableColor(color: newColor)
                eventsUpdated = true
                print("Updated event: \(events[i])")
            }
        }
        if eventsUpdated {
            saveEvents()
            print("Events updated and saved.")
        } else {
            print("No events updated.")
        }
    }

    func loadSubscriptionProduct() {
        Task { @MainActor in
            guard !isLoadingSubscription else { return }
            isLoadingSubscription = true
            defer { isLoadingSubscription = false }
            startTransactionListener()
            await refreshSubscriptionStatus()
            do {
                subscriptionProduct = try await Product.products(for: ["AP0001"]).first
                subscriptionMessage = subscriptionProduct == nil ? "Subscription information is unavailable. Please try again." : nil
            } catch { subscriptionMessage = error.localizedDescription }
        }
    }

    @MainActor
    func refreshSubscriptionStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == "AP0001", transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }

    @MainActor
    private func startTransactionListener() {
        guard transactionListener == nil else { return }
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result, transaction.productID == "AP0001" {
                    await transaction.finish()
                    await self.refreshSubscriptionStatus()
                    self.subscriptionMessage = nil
                }
            }
        }
    }

    func purchase() {
        Task { @MainActor in
            guard !isPurchasing else { return }
            guard let product = subscriptionProduct else {
                subscriptionMessage = "Load subscription information before purchasing."
                return
            }
            isPurchasing = true
            subscriptionMessage = nil
            defer { isPurchasing = false }
            do {
                switch try await product.purchase() {
                case .success(let result):
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                        await refreshSubscriptionStatus()
                    } else { subscriptionMessage = "The App Store could not verify this purchase. Please try restoring purchases." }
                case .pending: subscriptionMessage = "Your purchase is awaiting approval. Your subscription will update automatically when approved."
                case .userCancelled: break
                @unknown default: subscriptionMessage = "The purchase could not be completed. Please try again."
                }
            } catch { subscriptionMessage = error.localizedDescription }
        }
    }

    func restorePurchases() {
        Task { @MainActor in
            guard !isPurchasing else { return }
            isPurchasing = true
            defer { isPurchasing = false }
            do {
                try await AppStore.sync()
                await refreshSubscriptionStatus()
                subscriptionMessage = isSubscribed ? "Subscription restored." : "No active subscription was found."
            } catch { subscriptionMessage = error.localizedDescription }
        }
    }

    func deleteEvent(_ event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events = Recurrence.removingOccurrence(events[index], from: events)
            saveEvents()
        }
    }
}

// Extend AppData to conform to UNUserNotificationCenterDelegate
extension AppData: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) ->
            Void
    ) {
        print("Notification will present: \(notification.request.content.body)")
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "VIEW_ACTION" {
            print("Notification action triggered: \(response.actionIdentifier)")
        }
        completionHandler()
    }
}

// Helper function to decode from UserDefaults
private func decodeFromUserDefaults<T: Decodable>(
    _ type: T.Type, forKey key: String, suiteName: String
) -> T? {
    if let sharedDefaults = UserDefaults(suiteName: suiteName),
        let data = sharedDefaults.data(forKey: key)
    {
        let decoder = JSONDecoder()
        return try? decoder.decode(type, from: data)
    }
    return nil
}

// Helper function to encode to UserDefaults
private func encodeToUserDefaults<T: Encodable>(_ value: T, forKey key: String, suiteName: String) {
    if let sharedDefaults = UserDefaults(suiteName: suiteName) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(value) {
            sharedDefaults.set(encoded, forKey: key)
        }
    }
}

// Function to migrate user defaults to shared user defaults
func migrateUserDefaults() {
    let defaults = UserDefaults.standard
    let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier")

    // Migrate events
    if let oldEventsData = defaults.data(forKey: "events"),
        sharedDefaults?.data(forKey: "events") == nil
    {
        sharedDefaults?.set(oldEventsData, forKey: "events")
        defaults.removeObject(forKey: "events")
        print("Migrated events to shared UserDefaults.")
    }

    // Migrate categories
    if let oldCategoriesData = defaults.data(forKey: "categories"),
        sharedDefaults?.data(forKey: "categories") == nil
    {
        sharedDefaults?.set(oldCategoriesData, forKey: "categories")
        defaults.removeObject(forKey: "categories")
        print("Migrated categories to shared UserDefaults.")
    }

    AppPreferences.migrate()
}

enum RepeatUnit: String, Codable {
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
}
