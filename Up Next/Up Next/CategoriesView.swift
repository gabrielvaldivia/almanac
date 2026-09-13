//
//  CategoriesView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

extension Color {
    func toHex() -> String? {
        let components = UIColor(self).cgColor.components
        let r: CGFloat = components?[0] ?? 0
        let g: CGFloat = components?[1] ?? 0
        let b: CGFloat = components?[2] ?? 0
        return String(
            format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)),
            lroundf(Float(b * 255)))
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
    @Environment(\.editMode) private var editMode
    @State private var showingEditCategorySheet = false
    @State private var categoryToEdit:
        (
            name: String, color: Color, repeatOption: RepeatOption, customRepeatCount: Int,
            repeatUnit: String, repeatUntilOption: RepeatUntilOption, repeatUntilCount: Int,
            repeatUntil: Date
        )?
    @State private var showColorPickerSheet = false
    @State private var dailyNotificationTime = Date()
    @State private var isNotificationEnabled = false

    var body: some View {
        Form {
            // Categories section
            Section {
                ForEach(appData.categories.indices, id: \.self) { index in
                    Button {
                        categoryToEdit = appData.categories[index]
                        showingEditCategorySheet = true
                    } label: {
                        HStack {
                            Text(appData.categories[index].name).foregroundStyle(.primary)
                            Spacer()
                            Circle().fill(appData.categories[index].color).frame(width: 24, height: 24)
                        }
                    }.disabled(editMode?.wrappedValue == .active)
                }
                .onDelete(perform: removeCategory)
                .onMove(perform: moveCategory)
            }

            // Add Category button
            HStack {
                Button(action: {
                    showingAddCategorySheet = true
                    newCategoryName = ""
                    newCategoryColor = Color(
                        red: Double.random(in: 0.1...0.9), green: Double.random(in: 0.1...0.9),
                        blue: Double.random(in: 0.1...0.9))
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
                    appData.categories.append(
                        (
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
                CategoryForm(
                    showingSheet: $showingEditCategorySheet,
                    isEditing: true,
                    editingCategory: category,
                    onSave: { updatedCategory in
                        if let index = appData.categories.firstIndex(where: {
                            $0.name == category.name
                        }) {
                            appData.categories[index] = updatedCategory
                            appData.saveCategories()
                            appData.updateEventsForCategoryChange(
                                oldName: category.name, newName: updatedCategory.name,
                                newColor: updatedCategory.color)
                        }
                        categoryToEdit = nil  // Reset categoryToEdit after saving
                    }
                )
                .environmentObject(appData)
            }
        }
        .onChange(of: showingEditCategorySheet) { oldValue, newValue in
            if !newValue {
                categoryToEdit = nil  // Reset categoryToEdit when sheet is dismissed
            }
        }

    }

    private func removeCategory(at offsets: IndexSet) {
        let names = Set(offsets.compactMap { appData.categories.indices.contains($0) ? appData.categories[$0].name : nil })
        appData.categories.remove(atOffsets: offsets)
        for index in appData.events.indices where names.contains(appData.events[index].category ?? "") {
            appData.events[index].category = nil
        }
        if names.contains(appData.defaultCategory) { appData.defaultCategory = "" }
        appData.saveEvents()
    }

    private func moveCategory(from source: IndexSet, to destination: Int) {
        appData.categories.move(fromOffsets: source, toOffset: destination)
    }
}
