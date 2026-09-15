//
//  SettingsView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/6/24.
//

import Foundation
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingDeleteAllAlert = false
    @State private var showingRestoreBackupAlert = false
    @Environment(\.openURL) var openURL
    @State private var selectedAppIcon =
        UserDefaults.standard.string(forKey: "selectedAppIcon") ?? "Default"
    @State private var showingAppIconSheet = false
    @State private var showingCategoryManagementSheet = false
    @State private var showingContactBirthdays = false

    var body: some View {
        Form {
            if let error = appData.storageError {
                Section("Data Recovery") {
                    Text(error).font(.footnote)
                    Button("Retry Loading") { appData.loadEvents() }
                    Button("Restore Last Readable Backup") { showingRestoreBackupAlert = true }
                        .alert("Restore backup?", isPresented: $showingRestoreBackupAlert) {
                            Button("Restore", role: .destructive) { appData.restoreEventBackup() }
                            Button("Cancel", role: .cancel) {}
                        } message: { Text("This replaces the current event list with the last readable backup. The unreadable original remains preserved separately.") }
                }
            }
            // Notifications Section
            Section(header: Text("Notifications")) {
                Toggle("Daily Notification", isOn: Binding(
                    get: { appData.dailyNotificationEnabled },
                    set: { appData.setDailyNotification(enabled: $0) }))
                if appData.dailyNotificationEnabled {
                    DatePicker("Notification Time", selection: $appData.notificationTime, displayedComponents: .hourAndMinute)
                    if let status = appData.notificationStatus {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Contacts") {
                Button {
                    showingContactBirthdays = true
                } label: {
                    HStack {
                        Text("Sync Birthdays")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tint)
                    }
                }
                .accessibilityIdentifier("syncContactBirthdays")
            }

            // Categories Section
            Section(header: Text("Categories")) {
                HStack {
                    Text("Default Category")
                        .foregroundColor(.primary)
                    Spacer()
                    Menu {
                        Button(action: {
                            appData.defaultCategory = ""
                        }) {
                            Text("None").foregroundColor(.gray)
                        }
                        ForEach(appData.categories, id: \.name) { category in
                            Button(action: {
                                appData.defaultCategory = category.name
                            }) {
                                Text(category.name).foregroundColor(.gray)
                            }
                        }
                    } label: {
                        HStack {
                            Text(appData.defaultCategory.isEmpty ? "None" : appData.defaultCategory)
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(.tint)
                        }
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
                Button(action: {
                    showingCategoryManagementSheet = true
                }) {
                    HStack {
                        Text("Manage Categories")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tint)
                    }
                }
            }

            // Appearance Section
            Section(header: Text("Appearance")) {
                Button(action: {
                    showingAppIconSheet = true
                }) {
                    HStack {
                        Text("App Icon")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(selectedAppIcon)
                            .foregroundColor(.gray)
                    }
                }
                HStack {
                    Text("Event Style")
                    Spacer()
                    Menu {
                        Button(action: {
                            appData.eventStyle = "flat"
                        }) {
                            Text("Flat")
                            if appData.eventStyle == "flat" {
                                Image(systemName: "checkmark")
                            }
                        }
                        Button(action: {
                            appData.eventStyle = "bubbly"
                        }) {
                            Text("Bubbly")
                            if appData.eventStyle == "bubbly" {
                                Image(systemName: "checkmark")
                            }
                        }
                        Button(action: {
                            appData.eventStyle = "naked"
                        }) {
                            Text("Naked")
                            if appData.eventStyle == "naked" {
                                Image(systemName: "checkmark")
                            }
                        }
                    } label: {
                        HStack {
                            Text(appData.eventStyle.capitalized)
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(.tint)
                        }
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
            }

            // Support Section
            Section(header: Text("Support")) {
                Button(action: {
                    if let url = URL(string: "https://twitter.com/gabrielvaldivia") {
                        openURL(url)
                    }
                }) {
                    Text("Follow on Twitter")
                }

                Button(action: {
                    if let url = URL(
                        string: "https://itunes.apple.com/app/id6504696550?action=write-review")
                    {
                        openURL(url)
                    }
                }) {
                    Text("Rate on App Store")
                }

            }

            // Danger Zone Section
            Section(header: Text("Danger Zone")) {
                Button(action: {
                    showingDeleteAllAlert = true
                }) {
                    HStack {
                        Text("Delete All Events")
                    }
                    .foregroundColor(.red)
                }
                .alert(isPresented: $showingDeleteAllAlert) {
                    Alert(
                        title: Text("Delete All Events"),
                        message: Text(
                            "Are you sure you want to delete all events? This action cannot be undone."
                        ),
                        primaryButton: .destructive(Text("Delete")) {
                            deleteAllEvents()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }

        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingAppIconSheet) {
            AppIconSelectionView(selectedAppIcon: $selectedAppIcon)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingCategoryManagementSheet) {
            NavigationView {
                CategoriesView()
                    .environmentObject(appData)
            }
        }
        .sheet(isPresented: $showingContactBirthdays) {
            NavigationStack {
                ContactBirthdaysView()
                    .environmentObject(appData)
            }
            .presentationDetents([.large])
        }
        .onAppear {
            appData.scheduleDailyNotification()
            selectedAppIcon = AppIconSelectionView.appIcons.first { $0.2 == UIApplication.shared.alternateIconName }?.1 ?? "Default"
        }
    }

    // Function to delete all events
    private func deleteAllEvents() {
        guard appData.storageError == nil else { return }
        appData.events.removeAll()
        appData.saveEvents()
    }

    // Preview for SettingsView
    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            SettingsView()
                .environmentObject(AppData())
        }
    }

    struct AppIconSelectionView: View {
        @Binding var selectedAppIcon: String
        @State private var iconError: String?

        // Updated app icons array with tuples (previewName, displayName, iconName, author)
        static let appIcons: [(String, String, String?, (String, String)?)] = [
            ("DefaultPreview", "Default", nil, nil),
            ("DarkPreview", "Dark", "DarkAppIcon", nil),
            ("MonochromePreview", "Monochrome", "MonochromeAppIcon", nil),
            ("StarPreview", "Star", "StarAppIcon", nil),
            ("HeartPreview", "Heart", "HeartAppIcon", nil),
            ("DotGridPreview", "DotGrid", "DotGridAppIcon", nil),
            ("GlyphPreview", "Glyph", "GlyphAppIcon", nil),
            (
                "PixelPreview", "Pixel", "PixelAppIcon",
                ("Daniel Chung", "https://danielchung.design")
            ),
            ("1992Preview", "1992", "1992AppIcon", ("Sai Perchard", "https://perchard.com")),
            ("1993Preview", "1993", "1993AppIcon", ("Sai Perchard", "https://perchard.com")),
            ("2012Preview", "2012", "2012AppIcon", ("Charlie Deets", "https://charliedeets.com")),
            ("2013Preview", "2013", "2013AppIcon", ("Charlie Deets", "https://charliedeets.com")),
            (
                "AbstractPreview", "Abstract", "AbstractAppIcon",
                ("Cliff Warren", "https://cliffwarren.com")
            ),
            (
                "BubblePreview", "Bubble", "BubbleAppIcon",
                ("Pablo Stanley", "https://twitter.com/pablostanley")
            ),
            (
                "SkeuoPreview", "Skeuo", "SkeuoAppIcon",
                ("Pablo Stanley", "https://twitter.com/pablostanley")
            ),
            (
                "TimeBotPreview", "Time Bot", "TimeBotAppIcon",
                ("Pablo Stanley", "https://twitter.com/pablostanley")
            ),
            (
                "TimePiecePreview", "Time Piece", "TimePieceAppIcon",
                ("Pablo Stanley", "https://twitter.com/pablostanley")
            ),
        ]

        var body: some View {
            VStack {
                Text("App Icons")
                    .font(.headline)
                    .padding()

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(Self.appIcons, id: \.1) { icon in
                            VStack(spacing: 4) {
                                Button { changeAppIcon(to: icon.2, displayName: icon.1) } label: {
                                    VStack {
                                        Image(icon.0).resizable().aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 60).cornerRadius(12)
                                        Text(icon.1).font(.footnote).foregroundStyle(.primary)
                                    }
                                }.accessibilityLabel("\(icon.1) App Icon")
                                    .accessibilityValue(selectedAppIcon == icon.1 ? "Selected" : "")
                                if let author = icon.3, let url = URL(string: author.1) {
                                    Link("by \(author.0)", destination: url)
                                        .font(.caption2).multilineTextAlignment(.center)
                                }
                            }.frame(width: 90)

                        }
                    }
                    .padding()
                }
            }
            .alert("Couldn’t Change Icon", isPresented: Binding(get: { iconError != nil }, set: { if !$0 { iconError = nil } })) {
                Button("OK") { iconError = nil }
            } message: { Text(iconError ?? "") }
        }

        private func changeAppIcon(to iconName: String?, displayName: String) {
            UIApplication.shared.setAlternateIconName(iconName) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.iconError = error.localizedDescription
                    } else {
                        self.selectedAppIcon = displayName
                        UserDefaults.standard.set(displayName, forKey: "selectedAppIcon")
                        self.iconError = nil
                    }
                }
            }
        }

    }

}
