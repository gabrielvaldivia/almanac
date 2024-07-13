//
//  AddCategoryView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/13/24.
//

import SwiftUI

struct AddCategoryView: View {
    @EnvironmentObject var appData: AppData
    @Binding var showingAddCategorySheet: Bool
    @State private var newCategoryName: String = ""
    @State private var newCategoryColor: Color = .blue
    @FocusState private var isCategoryNameFieldFocused: Bool
    var onSave: ((name: String, color: Color)) -> Void

    var body: some View {
        Form {
            TextField("Category Name", text: $newCategoryName)
                .focused($isCategoryNameFieldFocused)
            ColorPicker("Color", selection: $newCategoryColor)
        }
        .navigationBarTitle("Add Category", displayMode: .inline)
        .navigationBarItems(
            leading: Button("Cancel") {
                showingAddCategorySheet = false
            },
            trailing: Button("Save") {
                let newCategory = (name: newCategoryName, color: newCategoryColor)
                appData.categories.append(newCategory)
                appData.saveCategories()  // Save categories to user defaults
                onSave(newCategory)
                showingAddCategorySheet = false
            }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCategoryNameFieldFocused = true
            }
        }
    }
}