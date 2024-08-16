//
//  SettingsView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/6/24.
//

import Foundation
import SwiftUI
import WidgetKit
import PassKit
import UIKit
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingDeleteAllAlert = false
    @Environment(\.openURL) var openURL
    @State private var dailyNotificationEnabled = UserDefaults.standard.bool(forKey: "dailyNotificationEnabled") // Load state from UserDefaults
    @State private var selectedAppIcon = "Default"
    @State private var iconChangeSuccess: Bool? 
    @State private var showingAppIconSheet = false
    @State private var showingSubscriptionAlert = false
    
    var body: some View {
        Form {
            // Notifications Section
            Section(header: Text("Notifications")) {
                Toggle("Daily Notification", isOn: $dailyNotificationEnabled)
                    .onChange(of: dailyNotificationEnabled) { oldValue, newValue in
                        appData.setDailyNotification(enabled: newValue)
                    }
                if dailyNotificationEnabled {
                    DatePicker("Notification Time", selection: $appData.notificationTime, displayedComponents: .hourAndMinute)
                }
            }
            
            // Categories Section
            Section(header: Text("Categories")) {
                HStack {
                    Text("Default Category")
                        .foregroundColor(.primary) // Use primary color for the label
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
                        // .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
                NavigationLink(destination: CategoriesView().environmentObject(appData)) {
                    Text("Manage Categories")
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
                    if let url = URL(string: "https://itunes.apple.com/app/id6504696550?action=write-review") {
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
                        message: Text("You are already subscribed to Almanac Pro. To manage your subscription, please go to your App Store settings."),
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
                        message: Text("Are you sure you want to delete all events? This action cannot be undone."),
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
        .onAppear {
            print("SettingsView appeared")
            dailyNotificationEnabled = UserDefaults.standard.bool(forKey: "dailyNotificationEnabled")
        }
    }
    
    // Function to delete all events
    private func deleteAllEvents() {
        appData.objectWillChange.send()  // Notify the view of changes
        appData.events.removeAll()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
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
    let appIcons = ["Default", "Dark", "Monochrome", "Star", "Heart", "X", "Dot Grid","Glyph", "Pixel", "1992", "1993","2012", "2013", "Abstract", "Bubble", "Skeuo", "Time Bot", "Time Piece"]
    
    // Dictionary to store author names and links
    let iconAuthors: [String: (name: String, link: String)] = [
        "1992": ("Sai Perchard", "https://www.perchard.com/"),
        "1993": ("Sai Perchard", "https://www.perchard.com/"),
        "2012": ("Charlie Deets", "https://charliedeets.com"),
        "2013": ("Charlie Deets", "https://charliedeets.com"),
        "Abstract": ("Cliff Warren", "http://www.cliffwarren.com"),
        "Bubble": ("Pablo Stanley", "https://x.com/pablostanley"),
        "Time Piece": ("Pablo Stanley", "https://x.com/pablostanley"),
        "Time Bot": ("Pablo Stanley", "https://x.com/pablostanley"),
        "Skeuo": ("Pablo Stanley", "https://x.com/pablostanley"),
        "Pixel": ("Daniel Chung", "https://www.danielchung.tech/")
    ]
    
    var body: some View {
        VStack {
            Text("App Icons")
                .font(.headline)
                .padding()
                .foregroundColor(.primary)

            Spacer()
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(appIcons, id: \.self) { icon in
                        Button(action: {
                            selectedAppIcon = icon
                            changeAppIcon(to: icon)
                            dismiss()
                        }) {
                            VStack(alignment: .center, spacing: 4) {
                                Image(uiImage: iconImage(for: icon))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
                                
                                IconLabel(icon: icon, author: iconAuthors[icon], openURL: openURL)
                                
                                Spacer()
                            }
                            .frame(width: 100, height: 140, alignment: .top)
                        }
                    }
                }
                .padding()
                
            }
            
            Spacer()
            
            HStack {
                Text("Want to add your own? ")
                    .foregroundColor(.secondary)
                Button("Submit a proposal") {
                    openEmail()
                }
                .foregroundColor(.blue)
            }
            .font(.footnote)
            .padding(.bottom, 8)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private func changeAppIcon(to iconName: String) {
        let iconToSet: String?
        switch iconName {
        case "Default":
            iconToSet = nil
        case "Dark":
            iconToSet = "DarkAppIcon"
        case "Monochrome":
            iconToSet = "MonochromeAppIcon"
        case "Star":
            iconToSet = "StarAppIcon"
        case "Heart":
            iconToSet = "HeartAppIcon"
        case "X":
            iconToSet = "XAppIcon"
        case "Dot Grid":
            iconToSet = "DotGridAppIcon"
        case "Glyph":
            iconToSet = "GlyphAppIcon"
        case "1992":
            iconToSet = "1992AppIcon"
        case "1993":
            iconToSet = "1993AppIcon"
        case "2012":
            iconToSet = "2012AppIcon"
        case "2013":
            iconToSet = "2013AppIcon"
        case "Abstract":
            iconToSet = "AbstractAppIcon"
        case "Bubble":
            iconToSet = "BubbleAppIcon"
        case "Time Piece":
            iconToSet = "TimePieceAppIcon"
        case "Time Bot":
            iconToSet = "TimeBotAppIcon"
        case "Skeuo":
            iconToSet = "ArrowAppIcon"
        case "Pixel":
            iconToSet = "PixelAppIcon"
        default:
            iconToSet = nil
        }
        
        UIApplication.shared.setAlternateIconName(iconToSet) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error changing app icon: \(error.localizedDescription)")
                    self.iconChangeSuccess = false
                } else {
                    print("App icon successfully changed to: \(iconName)")
                    self.selectedAppIcon = iconName
                    self.iconChangeSuccess = true
                }
            }
        }
    }

        private func iconImage(for iconName: String) -> UIImage {
            let iconToLoad: String?
            switch iconName {
            case "Default":
                iconToLoad = nil
            case "Dark":
                iconToLoad = "DarkAppIcon"
            case "Monochrome":
                iconToLoad = "MonochromeAppIcon"
            case "Star":
                iconToLoad = "StarAppIcon"
            case "Heart":
                iconToLoad = "HeartAppIcon"
            case "X":
                iconToLoad = "XAppIcon"
            case "Glyph":
                iconToLoad = "GlyphAppIcon"
            case "Arrow (B&W)":
                iconToLoad = "ArrowBWAppIcon"
            case "Dot Grid":
                iconToLoad = "DotGridAppIcon"
            case "1992":
                iconToLoad = "1992AppIcon"
            case "1993":
                iconToLoad = "1993AppIcon"
            case "2012":
                iconToLoad = "2012AppIcon"
            case "2013":
                iconToLoad = "2013AppIcon"
            case "Abstract":
                iconToLoad = "AbstractAppIcon"
            case "Bubble":
                iconToLoad = "BubbleAppIcon"
            case "Time Piece":
                iconToLoad = "TimePieceAppIcon"
            case "Time Bot":
                iconToLoad = "TimeBotAppIcon"
            case "Skeuo":
                iconToLoad = "ArrowAppIcon"
            case "Pixel":
                iconToLoad = "PixelAppIcon"
            default:
                iconToLoad = nil
            }
            
            if let iconName = iconToLoad, let alternateIcon = UIImage(named: iconName) {
                return alternateIcon
            } else {
                // Return the default app icon
                return UIImage(named: "AppIcon") ?? UIImage(systemName: "app.fill")!
            }
        }

    private func openEmail() {
        if let url = URL(string: "mailto:gabe@valdivia.works") {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    print("Failed to open email client")
                }
            }
        }
    }
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
                    .foregroundColor(.secondary) +
                Text(author.name)
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