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

typealias EventCategory = (
    name: String, color: Color, repeatOption: RepeatOption, customRepeatCount: Int,
    repeatUnit: String, repeatUntilOption: RepeatUntilOption, repeatUntilCount: Int,
    repeatUntil: Date, keywords: [String]
)

// Main class for managing app data
class AppData: NSObject, ObservableObject {
    static let shared = AppData()  // Singleton instance

    @Published var events: [Event] = []
    @Published var categories: [EventCategory] = [
        ("Work", .blue, .never, 1, "Days", .indefinitely, 1, Date(), []),
        ("Social", .green, .never, 1, "Days", .indefinitely, 1, Date(), []),
        ("Birthdays", .red, .yearly, 1, "Years", .indefinitely, 1, Date(), []),
        ("Holidays", .purple, .yearly, 1, "Years", .indefinitely, 1, Date(), []),
    ] {
        didSet {
            if isDataLoaded {
                if !isLoadingCategories { saveCategories() }
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
    private var revokedTransactionIDs: Set<UInt64> = []
    private var entitlementRefreshRevision = 0

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
        #if DEBUG && targetEnvironment(simulator)
        // Seed layout fixtures through the real store without making a timeline
        // test create and delete every row through a cold software keyboard.
        if AppPreferences.uiTestSuiteName != nil,
           AppPreferences.shared.data(forKey: "events") == nil,
           let json = ProcessInfo.processInfo.environment["ALMANAC_UI_TEST_EVENTS"] {
            do {
                try eventStore.save(EventStore.decode(Data(json.utf8)))
            } catch {
                fatalError("Invalid UI test events: \(error)")
            }
        }
        #endif
        loadEvents()
        isDataLoaded = true
        UNUserNotificationCenter.current().delegate = self
    }

    deinit { transactionListener?.cancel() }

    @Published var categoryStorageError: String?
    private var isLoadingCategories = false

    // Function to save categories to UserDefaults
    func saveCategories() {
        guard categoryStorageError == nil else { return }
        do {
            try CategoryStorage.save(categoryRecords(categories))
            WidgetCenter.shared.reloadAllTimelines()
        } catch { categoryStorageError = "Categories could not be saved. The original data is preserved. \(error.localizedDescription)" }
    }

    private func categoryRecords(_ categories: [EventCategory]) -> [CategoryData] {
        categories.map {
            CategoryData(
                name: $0.name, color: CodableColor(color: $0.color), repeatOption: $0.repeatOption,
                showRepeatOptions: false, customRepeatCount: $0.customRepeatCount,
                repeatUnit: $0.repeatUnit, repeatUntilOption: $0.repeatUntilOption,
                repeatUntilCount: $0.repeatUntilCount, repeatUntil: $0.repeatUntil, keywords: $0.keywords)
        }
    }

    // Function to load categories from UserDefaults
    func loadCategories() {
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        guard let data = AppPreferences.shared.data(forKey: "categories") else { return }
        do {
            let decoded = try CategoryStorage.decode(data)
            categoryStorageError = nil
            self.categories = decoded.map { categoryData in
                return (
                    name: categoryData.name, color: categoryData.color.color,
                    repeatOption: categoryData.repeatOption,
                    customRepeatCount: categoryData.customRepeatCount,
                    repeatUnit: categoryData.repeatUnit,
                    repeatUntilOption: categoryData.repeatUntilOption,
                    repeatUntilCount: categoryData.repeatUntilCount,
                    repeatUntil: categoryData.repeatUntil, keywords: categoryData.keywords
                )
            }
        } catch {
            if AppPreferences.shared.data(forKey: "categories.preservedOriginal") == nil {
                AppPreferences.shared.set(data, forKey: "categories.preservedOriginal")
            }
            categoryStorageError = "Categories could not be read. Editing is paused and the original data is preserved. \(error.localizedDescription)"
        }
    }

    @Published var storageError: String?
    private let eventStore = EventStore()

    func loadEvents() {
        do {
            let loaded = try eventStore.load()
            events = Recurrence.replenishing(loaded).map { event in
                var updated = event; updated.calendarSchemaVersion = 1; return updated
            }
            if events.count != loaded.count || loaded.contains(where: { $0.calendarSchemaVersion == 0 || ($0.seriesID != nil && $0.recurrence == nil) }) {
                try eventStore.save(events)
            }
            storageError = nil
            notificationTime = AppPreferences.reminderTime()
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

    var reviewedBirthdayContactIDs: Set<String> {
        Set(AppPreferences.shared.stringArray(forKey: "reviewedBirthdayContactIDs") ?? [])
    }

    @MainActor
    func saveContactBirthdays(_ birthdays: [ContactBirthday], selectedIDs: Set<String>) throws {
        if let message = storageError ?? categoryStorageError {
            throw NSError(domain: "BirthdayImport", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let category = categories.first { $0.name.localizedCaseInsensitiveCompare("Birthdays") == .orderedSame }
        let updated = BirthdayImport.applying(birthdays, selectedIDs: selectedIDs, to: events,
                                              category: category?.name ?? "Birthdays",
                                              color: CodableColor(color: category?.color ?? .red))
        // Commit before publishing, so a failed save leaves the review and existing events intact.
        try eventStore.save(updated)
        events = updated
        if category == nil, !selectedIDs.isEmpty {
            categories.append(("Birthdays", .red, .yearly, 1, "Years", .indefinitely, 1, Date(), []))
        }
        let reviewed = reviewedBirthdayContactIDs.union(birthdays.map(\.id))
        AppPreferences.shared.set(Array(reviewed).sorted(), forKey: "reviewedBirthdayContactIDs")
        WidgetCenter.shared.reloadAllTimelines()
        scheduleDailyNotification()
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
            guard !enabled || storageError == nil else {
                notificationStatus = "Existing reminders are preserved until your saved events can be read."
                return
            }
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            let plan = enabled && allowed ? NotificationPlan.make(events: snapshot, hour: time.hour ?? 8, minute: time.minute ?? 0) : []
            let error = await NotificationScheduler.shared.replace(with: plan)
            if let error { notificationStatus = "Could not schedule reminders: \(error)" }
            else if enabled && !allowed { notificationStatus = "Notifications are blocked. Enable them in iOS Settings." }
            else { notificationStatus = enabled && plan.isEmpty ? "No upcoming reminders to schedule." : nil }
        }
    }

    func waitForNotifications() async { await notificationTask?.value }

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

    var canEditExistingCategories: Bool { storageError == nil && categoryStorageError == nil }

    @discardableResult
    func updateCategory(named oldName: String, with category: EventCategory) -> Bool {
        guard canEditExistingCategories,
              let index = categories.firstIndex(where: { $0.name == oldName }),
              CategoryName.isValid(category.name, existing: categories.map(\.name), excluding: oldName) else { return false }
        let previousColor = CodableColor(color: categories[index].color)
        let updatedColor = CodableColor(color: category.color)
        let updatedEvents = events.map { event -> Event in
            guard event.category == oldName else { return event }
            var updated = event
            updated.category = category.name
            if previousColor != updatedColor && updated.color == previousColor {
                updated.color = updatedColor
            }
            return updated
        }
        var updatedCategories = categories
        updatedCategories[index] = category
        return commitCategoryChange(updatedCategories, events: updatedEvents,
                                    defaultCategory: defaultCategory == oldName ? category.name : defaultCategory)
    }

    @discardableResult
    func removeCategories(at offsets: IndexSet) -> Bool {
        guard canEditExistingCategories, !offsets.isEmpty,
              offsets.allSatisfy({ categories.indices.contains($0) }) else { return false }
        let names = Set(offsets.map { categories[$0].name })
        var updatedCategories = categories
        updatedCategories.remove(atOffsets: offsets)
        let updatedEvents = events.map { event -> Event in
            guard let category = event.category, names.contains(category) else { return event }
            var updated = event
            updated.category = nil
            return updated
        }
        return commitCategoryChange(updatedCategories, events: updatedEvents,
                                    defaultCategory: names.contains(defaultCategory) ? "" : defaultCategory)
    }

    private func commitCategoryChange(_ updatedCategories: [EventCategory], events updatedEvents: [Event],
                                      defaultCategory updatedDefault: String) -> Bool {
        let defaults = AppPreferences.shared
        let previous = ["events", "events.lastReadableBackup", "categories", "categories.lastReadableBackup"].map {
            (key: $0, data: defaults.data(forKey: $0))
        }
        func restorePreviousPayloads() {
            for (key, data) in previous {
                if let data { defaults.set(data, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        // Publish only after both saves succeed. Retain the readable backups
        // and original payloads if either store refuses the dependent change.
        do { try eventStore.save(updatedEvents) }
        catch {
            restorePreviousPayloads()
            storageError = "Could not save events: \(error.localizedDescription)"
            return false
        }
        do { try CategoryStorage.save(categoryRecords(updatedCategories)) }
        catch {
            restorePreviousPayloads()
            categoryStorageError = "Categories could not be saved. The original data is preserved. \(error.localizedDescription)"
            return false
        }
        isLoadingCategories = true
        categories = updatedCategories
        isLoadingCategories = false
        events = updatedEvents
        defaultCategory = updatedDefault
        WidgetCenter.shared.reloadAllTimelines()
        scheduleDailyNotification()
        return true
    }

    func loadSubscriptionProduct() {
        Task { @MainActor in
            guard !isLoadingSubscription else { return }
            isLoadingSubscription = true
            defer { isLoadingSubscription = false }
            startTransactionListener()
            // Product information must not wait for a slow receipt synchronization.
            async let entitlementRefresh: Void = refreshSubscriptionStatus()
            do {
                subscriptionProduct = try await Product.products(for: ["AP0001"]).first
                subscriptionMessage = subscriptionProduct == nil ? "Subscription information is unavailable. Please try again." : nil
            } catch { subscriptionMessage = error.localizedDescription }
            await entitlementRefresh
        }
    }

    @MainActor
    func refreshSubscriptionStatus() async {
        entitlementRefreshRevision += 1
        let revision = entitlementRefreshRevision
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == "AP0001",
               transaction.revocationDate == nil, !revokedTransactionIDs.contains(transaction.id),
               transaction.expirationDate.map({ $0 > Date() }) ?? true {
                active = true
            }
        }
        if revision == entitlementRefreshRevision { isSubscribed = active }
    }

    @MainActor
    private func startTransactionListener() {
        guard transactionListener == nil else { return }
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result, transaction.productID == "AP0001" {
                    // StoreKit's entitlement cache can lag behind a verified refund update.
                    if transaction.revocationDate != nil { self.revokedTransactionIDs.insert(transaction.id) }
                    await self.refreshSubscriptionStatus()
                    self.subscriptionMessage = nil
                    await transaction.finish()
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
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "VIEW_ACTION" {
        }
        completionHandler()
    }
}

// Function to migrate user defaults to shared user defaults
func migrateUserDefaults() {
    guard AppPreferences.uiTestSuiteName == nil else { return }
    let defaults = UserDefaults.standard
    let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier")

    // Migrate events
    if let oldEventsData = defaults.data(forKey: "events"),
        sharedDefaults?.data(forKey: "events") == nil
    {
        sharedDefaults?.set(oldEventsData, forKey: "events")
        defaults.removeObject(forKey: "events")
    }

    // Migrate categories
    if let oldCategoriesData = defaults.data(forKey: "categories"),
        sharedDefaults?.data(forKey: "categories") == nil
    {
        sharedDefaults?.set(oldCategoriesData, forKey: "categories")
        defaults.removeObject(forKey: "categories")
    }

    AppPreferences.migrate()
}
