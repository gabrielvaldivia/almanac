//
//  SettingsView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/6/24.
//

import Foundation
import SwiftUI
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingDeleteAllAlert = false

    var body: some View {
        Form {
            Section(header: Text("Notifications")) {
                DatePicker("Notification Time", selection: $appData.notificationTime, displayedComponents: .hourAndMinute)
            }
            
            Section(header: Text("Categories")) {
                
                Picker("Default Category", selection: Binding(
                    get: {
                        if let firstCategory = appData.categories.first?.name, appData.defaultCategory.isEmpty {
                            return firstCategory
                        }
                        return appData.defaultCategory
                    },
                    set: { appData.defaultCategory = $0 }
                )) {
                    ForEach(appData.categories, id: \.name) { category in
                        Text(category.name)
                            .tag(category.name)
                            .foregroundColor(.gray) // Set the text color to gray
                    }
                }
                .pickerStyle(MenuPickerStyle())
                NavigationLink(destination: CategoriesView().environmentObject(appData)) {
                    Text("Manage Categories")
                }
            }
            
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
    }
    
    private func deleteAllEvents() {
        appData.objectWillChange.send()  // Notify the view of changes
        appData.events.removeAll()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppData())
    }
}