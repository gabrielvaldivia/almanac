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
import StoreKit

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
    @State private var categoryToEdit: (index: Int, name: String, color: Color)?
    @State private var showColorPickerSheet = false
    @State private var showingSubscriptionSheet = false

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
                            categoryToEdit = (index: index, name: appData.categories[index].name, color: appData.categories[index].color)
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
            NavigationView {
                AddCategoryView(
                    showingAddCategorySheet: $showingAddCategorySheet,
                    onSave: { newCategory in
                        appData.categories.append((name: newCategory.name, color: newCategory.color))
                        appData.saveCategories()
                    }
                )
                .environmentObject(appData)
            }
            .presentationDetents([.medium])
        }

        // Edit Category Sheet
        .sheet(isPresented: $showingEditCategorySheet) {
            EditCategorySheet(
                categoryToEdit: $categoryToEdit,
                showingEditCategorySheet: $showingEditCategorySheet,
                showColorPickerSheet: $showColorPickerSheet
            )
            .environmentObject(appData)
            .presentationDetents([.medium])
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
                            updateEventsForCategoryChange(oldName: oldName, newName: newName)
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

    private func updateEventsForCategoryChange(oldName: String, newName: String) {
        for i in 0..<appData.events.count {
            if appData.events[i].category == oldName {
                appData.events[i].category = newName
            }
        }
        appData.objectWillChange.send()
        appData.saveEvents()
    }

    private func deleteAllEvents() {
        appData.objectWillChange.send()
        appData.events.removeAll()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
    }
}