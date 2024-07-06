//
//  CategoriesView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import UIKit  // Ensure UIKit is imported for UIColor
import WidgetKit  // Add this import

extension Color {
    func toHex() -> String? {
        let components = UIColor(self).cgColor.components
        let r: CGFloat = components?[0] ?? 0
        let g: CGFloat = components?[1] ?? 0
        let b: CGFloat = components?[2] ?? 0
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}

struct CategoriesView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingAddCategorySheet = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = Color.blue  // Default color for new category
    @FocusState private var isCategoryNameFieldFocused: Bool  // Add this line
    @State private var showingDeleteAllAlert = false
    @State private var selectedCategory: String?  // Add this line

    var body: some View {
        Form {  // Change List to Form
            // Categories section 
            Section() {
                ForEach(appData.categories.indices, id: \.self) { index in
                    HStack {
                        TextField("Category Name", text: Binding(
                            get: { 
                                if self.appData.categories.indices.contains(index) {
                                    return self.appData.categories[index].name
                                }
                                return ""
                            },
                            set: { 
                                if self.appData.categories.indices.contains(index) {
                                    let oldName = self.appData.categories[index].name
                                    self.appData.categories[index].name = $0
                                    updateEventsForCategoryChange(oldName: oldName, newName: $0)
                                    if selectedCategory == oldName {  // Update selectedCategory if it matches oldName
                                        selectedCategory = $0
                                    }
                                    appData.saveCategories()  // Save categories to user defaults
                                }
                            }
                        ))
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { 
                                if self.appData.categories.indices.contains(index) {
                                    return self.appData.categories[index].color
                                }
                                return .clear
                            },
                            set: { 
                                if self.appData.categories.indices.contains(index) {
                                    self.appData.categories[index].color = $0
                                }
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                        .padding(.trailing, 10)
                    }
                }
                .onDelete(perform: removeCategory)
                .onMove(perform: moveCategory)
            }
            
            // Add Category button
            HStack {
                Button(action: {
                    showingAddCategorySheet = true
                    newCategoryName = ""
                    newCategoryColor = Color(red: Double.random(in: 0.1...0.9), green: Double.random(in: 0.1...0.9), blue: Double.random(in: 0.1...0.9))  // Ensure middle range color
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Category")
                    }
                }
            }
        }
        .formStyle(GroupedFormStyle()) 
        .navigationBarTitle("Manage Categories", displayMode: .inline)
        .navigationBarItems(trailing: EditButton())  // Move Edit button to the top right
        
        // Add Category Sheet
        .sheet(isPresented: $showingAddCategorySheet) {
            NavigationView {
                Form {
                    TextField("Category Name", text: $newCategoryName)
                        .focused($isCategoryNameFieldFocused)  // Ensure the TextField is focused
                    ColorPicker("Choose Color", selection: $newCategoryColor)
                }
                .formStyle(GroupedFormStyle())  // Add this line
                .navigationBarTitle("Add Category", displayMode: .inline)  // Add this line
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingAddCategorySheet = false
                    },
                    trailing: Button("Save") {
                        let newCategory = (name: newCategoryName, color: newCategoryColor)
                        appData.categories.append(newCategory)
                        appData.saveCategories()  // Save categories to user defaults
                        showingAddCategorySheet = false
                    }
                )
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isCategoryNameFieldFocused = true  // Delay focusing the TextField
                }
            }
            .presentationDetents([.medium])  // Add this line to set the sheet size to medium
        }
        .onAppear {
            appData.loadCategories()
            if appData.defaultCategory.isEmpty, let firstCategory = appData.categories.first?.name {
                appData.defaultCategory = firstCategory
            }
        }
    }

    private func removeCategory(at offsets: IndexSet) {
        DispatchQueue.main.async {
            if let index = offsets.first, index < self.appData.categories.count {
                let removedCategory = self.appData.categories[index].name
                self.appData.categories.remove(at: index)
                appData.saveCategories()  // Save categories to user defaults
                
                // Update defaultCategory if the removed category was the default one
                if appData.defaultCategory == removedCategory {
                    appData.defaultCategory = appData.categories.first?.name ?? ""
                }
            }
        }
    }

    private func moveCategory(from source: IndexSet, to destination: Int) {
        DispatchQueue.main.async {
            appData.categories.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func updateDailyNotificationTime(_ time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Today's events"
        
        // Ensure appData is accessed correctly
        let todayEvents = appData.getTodayEvents()  // Corrected method name
        let eventTitles = todayEvents.map { $0.title }.joined(separator: ", ")
        content.body = eventTitles.isEmpty ? "No events due today." : eventTitles
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "dailyNotification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    private func updateEventsForCategoryChange(oldName: String, newName: String) {
        for i in 0..<appData.events.count {
            if appData.events[i].category == oldName {
                appData.events[i].category = newName
            }
        }
        appData.objectWillChange.send()  // Notify the view of changes
    }
    
    private func deleteAllEvents() {
        appData.objectWillChange.send()  // Notify the view of changes
        appData.events.removeAll()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
    }
}
