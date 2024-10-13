//
//  CategoriesView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import UIKit
import WidgetKit
import UserNotifications

extension Color {
    func toHex() -> String? {
        let components = UIColor(self).cgColor.components
        let r: CGFloat = components?[0] ?? 0
        let g: CGFloat = components?[1] ?? 0
        let b: CGFloat = components?[2] ?? 0
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}

struct PresentingViewController: UIViewControllerRepresentable {
    var onPresent: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        DispatchQueue.main.async {
            self.onPresent(viewController)
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct CategoriesView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingAddCategorySheet = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = Color.blue
    @FocusState private var isCategoryNameFieldFocused: Bool
    @State private var showingDeleteAllAlert = false
    @State private var selectedCategory: String?
    @State private var tempCategoryNames: [String] = []
    @Environment(\.editMode) private var editMode
    @State private var showingEditCategorySheet = false
    @State private var categoryToEdit: (name: String, color: Color, repeatOption: RepeatOption, customRepeatCount: Int, repeatUnit: String, repeatUntilOption: RepeatUntilOption, repeatUntilCount: Int, repeatUntil: Date)?
    @State private var showColorPickerSheet = false
    @State private var dailyNotificationTime = Date()
    @State private var isNotificationEnabled = false

    var body: some View {
        Form {
            // Categories section
            Section {
                ForEach(appData.categories.indices, id: \.self) { index in
                    HStack {
                        if editMode?.wrappedValue == .active {
                            TextField("Category Name", text: Binding(
                                get: {
                                    if self.tempCategoryNames.indices.contains(index) {
                                        return self.tempCategoryNames[index]
                                    }
                                    return ""
                                },
                                set: {
                                    if self.tempCategoryNames.indices.contains(index) {
                                        self.tempCategoryNames[index] = $0
                                    }
                                }
                            ))
                        } else {
                            HStack {
                                Text(self.appData.categories[index].name)
                            }
                        }
                        Spacer()
                        Circle()
                            .fill(self.appData.categories.indices.contains(index) ? self.appData.categories[index].color : .clear)
                            .frame(width: 24, height: 24)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if editMode?.wrappedValue != .active {
                            categoryToEdit = appData.categories[index]
                            showingEditCategorySheet = true
                        }
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
                    newCategoryColor = Color(red: Double.random(in: 0.1...0.9), green: Double.random(in: 0.1...0.9), blue: Double.random(in: 0.1...0.9))
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
        .navigationBarItems(trailing: EditButton())

        // Add Category View
        .sheet(isPresented: $showingAddCategorySheet) {
            CategoryForm(
                showingSheet: $showingAddCategorySheet,
                onSave: { newCategory in
                    appData.categories.append((
                        name: newCategory.name,
                        color: newCategory.color,
                        repeatOption: newCategory.repeatOption,
                        customRepeatCount: newCategory.customRepeatCount,
                        repeatUnit: newCategory.repeatUnit,
                        repeatUntilOption: newCategory.repeatUntilOption,
                        repeatUntilCount: newCategory.repeatUntilCount,
                        repeatUntil: newCategory.repeatUntil
                    ))
                    appData.saveCategories()
                }
            )
            .environmentObject(appData)
        }

        // Edit Category Sheet
        .sheet(isPresented: $showingEditCategorySheet) {
            if let category = categoryToEdit {
                NavigationView {
                    CategoryForm(
                        showingSheet: $showingEditCategorySheet,
                        isEditing: true,
                        editingCategory: category,
                        onSave: { updatedCategory in
                            if let index = appData.categories.firstIndex(where: { $0.name == category.name }) {
                                appData.categories[index] = updatedCategory
                                appData.saveCategories()
                                appData.updateEventsForCategoryChange(oldName: category.name, newName: updatedCategory.name, newColor: updatedCategory.color)
                            }
                            categoryToEdit = nil // Reset categoryToEdit after saving
                        }
                    )
                    .environmentObject(appData)
                    .navigationTitle("Edit Category")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .onChange(of: showingEditCategorySheet) { newValue in
            if !newValue {
                categoryToEdit = nil // Reset categoryToEdit when sheet is dismissed
            }
        }

        .onAppear {
            appData.loadCategories()
            if appData.defaultCategory.isEmpty, let firstCategory = appData.categories.first?.name {
                appData.defaultCategory = firstCategory
            }
        }
        .onChange(of: editMode?.wrappedValue) { oldValue, newValue in
            if newValue == .active {
                tempCategoryNames = appData.categories.map { $0.name }
            } else {
                for index in appData.categories.indices {
                    if index < tempCategoryNames.count {
                        let oldName = appData.categories[index].name
                        let newName = tempCategoryNames[index]
                        if oldName != newName {
                            appData.categories[index].name = newName
                            updateEventsForCategoryChange(oldName: oldName, newName: newName, newColor: appData.categories[index].color)
                        }
                    }
                }
                appData.saveCategories()
            }
        }
    }

    private func removeCategory(at offsets: IndexSet) {
        DispatchQueue.main.async {
            if let index = offsets.first, index < self.appData.categories.count {
                let removedCategory = self.appData.categories[index].name
                self.appData.categories.remove(at: index)
                appData.saveCategories()

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

        let todayEvents = appData.getTodayEvents()
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

    private func updateEventsForCategoryChange(oldName: String, newName: String, newColor: Color) {
        for i in 0..<appData.events.count {
            if appData.events[i].category == oldName {
                appData.events[i].category = newName
                appData.events[i].color = CodableColor(color: newColor)
            }
        }
        appData.objectWillChange.send()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
    }

    private func deleteAllEvents() {
        appData.objectWillChange.send()
        appData.events.removeAll()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
    }
}
