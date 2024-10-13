import Foundation
import SwiftUI

import SwiftUI

struct EditCategorySheet: View {
    @Binding var categoryToEdit: (index: Int, name: String, color: Color)?
    @Binding var showingEditCategorySheet: Bool
    @EnvironmentObject var appData: AppData
    @Binding var showColorPickerSheet: Bool
    @State private var editedName: String = ""
    @State private var editedColor: Color = .blue
    @State private var repeatOption: RepeatOption = .never
    @State private var showRepeatOptions: Bool = false
    @State private var customRepeatCount: Int = 1
    @State private var repeatUnit: String = "Days"
    @State private var repeatUntilOption: RepeatUntilOption = .indefinitely
    @State private var repeatUntilCount: Int = 1
    @State private var repeatUntil: Date = Date()

    var body: some View {
        NavigationView {
            CategoryForm(
                categoryName: $editedName,
                categoryColor: $editedColor,
                showColorPickerSheet: $showColorPickerSheet,
                repeatOption: $repeatOption,
                showRepeatOptions: $showRepeatOptions,
                customRepeatCount: $customRepeatCount,
                repeatUnit: $repeatUnit,
                repeatUntilOption: $repeatUntilOption,
                repeatUntilCount: $repeatUntilCount,
                repeatUntil: $repeatUntil,
                isEditing: true
            )
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingEditCategorySheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCategory()
                        showingEditCategorySheet = false
                    }
                    .disabled(editedName.isEmpty)
                }
            }
        }
        .onAppear {
            if let category = categoryToEdit {
                editedName = category.name
                editedColor = category.color
            }
        }
        .sheet(isPresented: $showColorPickerSheet) {
            CustomColorPickerSheet(selectedColor: Binding(
                get: { CodableColor(color: editedColor) },
                set: { editedColor = $0.color }
            ), showColorPickerSheet: $showColorPickerSheet)
        }
    }

    private func saveCategory() {
        if let index = categoryToEdit?.index {
            appData.categories[index].name = editedName
            appData.categories[index].color = editedColor
            appData.saveCategories()
            appData.updateEventsForCategoryChange(oldName: categoryToEdit!.name, newName: editedName, newColor: editedColor)
        }
    }
}