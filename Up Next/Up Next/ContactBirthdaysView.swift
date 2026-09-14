import ContactsUI
import SwiftUI

struct ContactBirthdaysView: View {
    @EnvironmentObject private var appData: AppData
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var access = BirthdayContactsStore.access
    @State private var snapshot: BirthdayContactsSnapshot?
    @State private var selectedIDs = Set<String>()
    @State private var loadedIDs = Set<String>()
    @State private var search = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingAccessPicker = false

    private var birthdays: [ContactBirthday] { snapshot?.birthdays ?? [] }
    private var visibleBirthdays: [ContactBirthday] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? birthdays : birthdays.filter { $0.name.localizedStandardContains(query) }
    }
    private var selectedCount: Int { birthdays.filter { selectedIDs.contains($0.id) }.count }

    var body: some View {
        content
            .navigationTitle("Contact Birthdays")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if snapshot != nil, !birthdays.isEmpty {
                        Button("Save") { save() }
                            .disabled(isLoading || appData.storageError != nil || appData.categoryStorageError != nil)
                            .accessibilityIdentifier("saveContactBirthdays")
                    }
                }
            }
            .task { await load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await load() } }
            }
            .alert("Couldn’t Sync Birthdays", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK", role: .cancel) { error = nil }
                } message: { Text(error ?? "") }
    }

    @ViewBuilder private var content: some View {
        if isLoading, snapshot == nil {
            ProgressView("Loading birthdays…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if access == .notDetermined {
            ContentUnavailableView {
                Label("Add Contact Birthdays", systemImage: "gift")
            } description: {
                Text("Connect Contacts, then choose which birthdays to add as yearly events. Nothing is added until you save.")
            } actions: {
                Button("Continue") { Task { await load(requestAccess: true) } }
                    .buttonStyle(.borderedProminent)
            }
        } else if access == .denied || access == .restricted {
            ContentUnavailableView {
                Label("Contacts Access Needed", systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                Text(access == .restricted
                     ? "Contacts access is restricted on this device. Your existing events are unchanged."
                     : "Allow Almanac to access Contacts in Settings, then return to choose birthdays.")
            } actions: {
                if access == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else if snapshot == nil {
            ContentUnavailableView {
                Label("Couldn’t Load Birthdays", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Your existing events are unchanged. Try reading Contacts again.")
            } actions: {
                Button("Try Again") { Task { await load() } }.buttonStyle(.borderedProminent)
            }
        } else {
            review
        }
    }

    private var review: some View {
        List {
            if let message = appData.storageError ?? appData.categoryStorageError {
                Section { Text(message).foregroundStyle(.secondary) }
            }
            if snapshot?.isLimited == true {
                Section {
                    Text("Only contacts you’ve shared with Almanac appear here.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if #available(iOS 18, *) {
                        Button("Choose More Contacts") { showingAccessPicker = true }
                            .contactAccessPicker(isPresented: $showingAccessPicker) { _ in
                                Task { await load() }
                            }
                    }
                }
            }
            if birthdays.isEmpty {
                ContentUnavailableView("No Birthdays Found", systemImage: "gift", description:
                    Text("Add birthdays to your contacts, then return here to sync them."))
            } else {
                Section {
                    HStack {
                        Text("\(selectedCount) of \(birthdays.count) selected")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("birthdaySelectionCount")
                        Spacer()
                        let visibleIDs = Set(visibleBirthdays.map(\.id))
                        let allSelected = !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedIDs)
                        Button(allSelected ? "Deselect All" : "Select All") {
                            if allSelected { selectedIDs.subtract(visibleIDs) }
                            else { selectedIDs.formUnion(visibleIDs) }
                        }
                        .disabled(visibleIDs.isEmpty)
                        .accessibilityHint("Applies to the birthdays shown in the list")
                    }
                } footer: {
                    Text("Choose birthdays to add as yearly events. Changes apply when you save.")
                }
                Section {
                    ForEach(visibleBirthdays) { birthday in
                        Toggle(isOn: Binding(
                            get: { selectedIDs.contains(birthday.id) },
                            set: { if $0 { selectedIDs.insert(birthday.id) } else { selectedIDs.remove(birthday.id) } })) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(birthday.name)
                                    Text(birthday.dateLabel)
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("birthday-\(birthday.id)")
                    }
                    if visibleBirthdays.isEmpty { Text("No matching birthdays").foregroundStyle(.secondary) }
                } footer: {
                    Text("Return here to review changes from Contacts. Turn off an imported birthday to remove its events from Almanac.")
                    if birthdays.contains(where: { $0.calendarIdentifier == .gregorian && $0.anchorDay.month == 2 && $0.anchorDay.day == 29 }) {
                        Text("February 29 birthdays fall on February 28 in other years.")
                    }
                }
            }
            if let count = snapshot?.unreadableBirthdayCount, count > 0 {
                Section { Text("\(count) contact birthdays couldn’t be read. Check their dates in Contacts.").foregroundStyle(.secondary) }
            }
        }
        .searchable(text: $search, prompt: "Search birthdays")
        .refreshable { await load() }
    }

    @MainActor private func load(requestAccess: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if requestAccess, BirthdayContactsStore.access == .notDetermined {
                try await BirthdayContactsStore.requestAccess()
            }
            access = BirthdayContactsStore.access
            guard access == .allowed else { snapshot = nil; return }
            let loaded = try await BirthdayContactsStore.load()
            try Task.checkCancellation()
            let ids = Set(loaded.birthdays.map(\.id))
            let defaults = BirthdayImport.selection(birthdays: loaded.birthdays, events: appData.events,
                                                    reviewedIDs: appData.reviewedBirthdayContactIDs)
            selectedIDs.formUnion(defaults.subtracting(loadedIDs))
            loadedIDs.formUnion(ids)
            snapshot = loaded
        } catch is CancellationError {
        } catch { self.error = error.localizedDescription }
    }

    @MainActor private func save() {
        guard !isLoading else { return }
        guard BirthdayContactsStore.access == .allowed else {
            access = BirthdayContactsStore.access
            snapshot = nil
            return
        }
        do {
            try appData.saveContactBirthdays(birthdays, selectedIDs: selectedIDs.intersection(Set(birthdays.map(\.id))))
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
