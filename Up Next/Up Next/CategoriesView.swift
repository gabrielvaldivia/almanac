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
    @State private var showingBackupConfirmation = false
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
                    Button("Restore Category Backup") { showingBackupConfirmation = true }
                        .disabled(appData.storageError != nil)
                }
            }
            if appData.storageError != nil {
                Section {
                    Text("Category edits and deletions are paused until your events can be read. Retry loading or restore your events in Settings.")
                        .font(.footnote)
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
        .alert("Restore category backup?", isPresented: $showingBackupConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Restore Backup") { appData.restoreCategoryBackup() }
        } message: {
            Text("Restore the last readable categories. Event details and colors stay intact. Events in categories missing from the backup become uncategorized.")
        }

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
                        appData.updateCategory(named: category.name, with: updatedCategory)
                        categoryToEdit = nil  // Reset categoryToEdit after saving
                    }
                )
                .environmentObject(appData)
            }
        }

    }

    private func removeCategory(at offsets: IndexSet) {
        appData.removeCategories(at: offsets)
    }

    private func moveCategory(from source: IndexSet, to destination: Int) {
        guard appData.categoryStorageError == nil else { return }
        appData.categories.move(fromOffsets: source, toOffset: destination)
    }
}
