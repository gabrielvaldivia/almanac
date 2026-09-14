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

struct CategoriesView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingAddCategorySheet = false
    private struct CategorySelection: Identifiable {
        let id: String
    }
    @Environment(\.editMode) private var editMode
    @State private var categoryToEdit: CategorySelection?

    var body: some View {
        Form {
            if let error = appData.categoryStorageError {
                Section {
                    Text(error).font(.footnote)
                    Button("Retry Loading Categories") { appData.loadCategories() }
                }
            }
            // Categories section
            Section {
                ForEach(appData.categories.indices, id: \.self) { index in
                    Button {
                        categoryToEdit = CategorySelection(id: appData.categories[index].name)
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
                    appData.categories.append(newCategory)
                }
            )
            .environmentObject(appData)
        }

        // Edit Category Sheet
        .sheet(item: $categoryToEdit) { selection in
            if let category = appData.categories.first(where: { $0.name == selection.id }) {
                CategoryForm(
                    showingSheet: Binding(get: { categoryToEdit != nil }, set: { if !$0 { categoryToEdit = nil } }),
                    isEditing: true,
                    editingCategory: category,
                    onSave: { updatedCategory in
                        if let index = appData.categories.firstIndex(where: {
                            $0.name == category.name
                        }) {
                            appData.categories[index] = updatedCategory
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

    }

    private func removeCategory(at offsets: IndexSet) {
        guard appData.categoryStorageError == nil else { return }
        let names = Set(offsets.compactMap { appData.categories.indices.contains($0) ? appData.categories[$0].name : nil })
        appData.categories.remove(atOffsets: offsets)
        for index in appData.events.indices where names.contains(appData.events[index].category ?? "") {
            appData.events[index].category = nil
        }
        if names.contains(appData.defaultCategory) { appData.defaultCategory = "" }
        appData.saveEvents()
    }

    private func moveCategory(from source: IndexSet, to destination: Int) {
        guard appData.categoryStorageError == nil else { return }
        appData.categories.move(fromOffsets: source, toOffset: destination)
    }
}
