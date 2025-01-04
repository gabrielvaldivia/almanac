//
//  SettingsView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/6/24.
//

import Foundation
import PassKit
import StoreKit
import SwiftUI
import UIKit
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingDeleteAllAlert = false
    @Environment(\.openURL) var openURL
    @State private var dailyNotificationEnabled = UserDefaults.standard.bool(
        forKey: "dailyNotificationEnabled")  // Load state from UserDefaults
    @State private var selectedAppIcon =
        UserDefaults.standard.string(forKey: "selectedAppIcon") ?? "Default"
    @State private var iconChangeSuccess: Bool?
    @State private var showingAppIconSheet = false
    @State private var showingSubscriptionAlert = false
    @State private var showingCategoryManagementSheet = false

    var body: some View {
        Form {
            // Notifications Section
            Section(header: Text("Notifications")) {
                Toggle("Daily Notification", isOn: $dailyNotificationEnabled)
                    .onChange(of: dailyNotificationEnabled) { oldValue, newValue in
                        appData.setDailyNotification(enabled: newValue)
                    }
                if dailyNotificationEnabled {
                    DatePicker(
                        "Notification Time", selection: $appData.notificationTime,
                        displayedComponents: .hourAndMinute)
                }
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
                                .foregroundColor(.gray)
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
                            .foregroundColor(.gray)
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
                                .foregroundColor(.gray)
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

                Button(action: {
                    if appData.isSubscribed {
                        showingSubscriptionAlert = true
                    } else {
                        appData.purchase()
                    }
                }) {
                    Text(appData.isSubscribed ? "Manage Subscription" : "Subscribe to Almanac Pro")
                }
                .alert(isPresented: $showingSubscriptionAlert) {
                    Alert(
                        title: Text("Subscription Active"),
                        message: Text(
                            "You are already subscribed to Almanac Pro. To manage your subscription, please go to your App Store settings."
                        ),
                        dismissButton: .default(Text("OK"))
                    )
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
                .presentationDetents([.height(230)])
        }
        .sheet(isPresented: $showingCategoryManagementSheet) {
            NavigationView {
                CategoriesView()
                    .environmentObject(appData)
            }
        }
        .onAppear {
            print("SettingsView appeared")
            dailyNotificationEnabled = UserDefaults.standard.bool(
                forKey: "dailyNotificationEnabled")
            selectedAppIcon = UserDefaults.standard.string(forKey: "selectedAppIcon") ?? "Default"
        }
    }

    // Function to delete all events
    private func deleteAllEvents() {
        appData.objectWillChange.send()  // Notify the view of changes
        appData.events.removeAll()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")  // Notify widget to reload
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
        @State private var iconChangeSuccess: Bool?
        @Environment(\.openURL) var openURL
        @Environment(\.dismiss) var dismiss

        // Updated app icons array with tuples (previewName, displayName, iconName, author)
        let appIcons: [(String, String, String?, (String, String)?)] = [
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
                "TimeBotPreview", "Time Bot", "TimebotAppIcon",
                ("Pablo Stanley", "https://twitter.com/pablostanley")
            ),
            (
                "TimePiecePreview", "Time Piece", "TimepieceAppIcon",
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
                        ForEach(appIcons, id: \.1) { icon in
                            VStack(alignment: .center, spacing: 4) {
                                Image(icon.0)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray, lineWidth: 0.5)
                                    )

                                Text(icon.1)
                                    .font(.footnote)
                                    .foregroundColor(.primary)

                                if let author = icon.3 {
                                    Text("by \(author.0)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .onTapGesture {
                                            if let url = URL(string: author.1) {
                                                openURL(url)
                                            }
                                        }
                                }
                            }
                            .frame(width: 90, height: icon.3 != nil ? 120 : 100)
                            .onTapGesture {
                                changeAppIcon(to: icon.2, displayName: icon.1)
                            }
                        }
                    }
                    .padding()
                }
            }
        }

        private func changeAppIcon(to iconName: String?, displayName: String) {
            UIApplication.shared.setAlternateIconName(iconName) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error changing app icon: \(error.localizedDescription)")
                        self.iconChangeSuccess = false
                    } else {
                        print("App icon successfully changed to: \(displayName)")
                        self.selectedAppIcon = displayName
                        UserDefaults.standard.set(displayName, forKey: "selectedAppIcon")
                        self.iconChangeSuccess = true
                    }
                }
            }
        }

        // ... rest of the code remains unchanged
    }

    struct IconLabel: View {
        let icon: String
        let author: (name: String, link: String)?
        let openURL: OpenURLAction

        var body: some View {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                if let author = author {
                    (Text("by ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        + Text(author.name)
                        .font(.caption)
                        .foregroundColor(.secondary))
                        .onTapGesture {
                            if let url = URL(string: author.link) {
                                openURL(url)
                            }
                        }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
