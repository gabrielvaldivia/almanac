import Foundation
import SwiftUI

struct EditCategorySheet: View {
    @Binding var categoryToEdit: (index: Int, name: String, color: Color)?
    @Binding var showingEditCategorySheet: Bool
    @EnvironmentObject var appData: AppData
    @FocusState private var isCategoryNameFieldFocused: Bool
    @Binding var showColorPickerSheet: Bool

    var body: some View {
        NavigationView {
            if let categoryToEdit = categoryToEdit {
                Form {
                    TextField("Category Name", text: Binding(
                        get: { categoryToEdit.name },
                        set: { self.categoryToEdit?.name = $0 }
                    ))
                    .focused($isCategoryNameFieldFocused)
                    HStack {
                        Text("Color")
                        Spacer()
                        Button(action: {
                            showColorPickerSheet = true
                        }) {
                            Circle()
                                .fill(categoryToEdit.color)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                .navigationBarTitle("Edit Category", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingEditCategorySheet = false
                    },
                    trailing: Button(action: {
                        print("Save button pressed")
                        let index = categoryToEdit.index
                        let oldName = appData.categories[index].name
                        let oldColor = appData.categories[index].color
                        appData.categories[index].name = categoryToEdit.name
                        appData.categories[index].color = categoryToEdit.color
                        appData.saveCategories()
                        
                        // Force a reload of events before updating
                        appData.loadEvents()
                        
                        print("Updating events for category change: \(oldName) -> \(categoryToEdit.name)")
                        appData.updateEventsForCategoryChange(oldName: oldName, newName: categoryToEdit.name, newColor: categoryToEdit.color)
                        
                        DispatchQueue.main.async {
                            appData.objectWillChange.send()
                        }
                        print("Closing edit sheet")
                        showingEditCategorySheet = false
                    }) {
                        Group {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(categoryToEdit.color)
                                    .frame(width: 60, height: 32)
                                Text("Save")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(CustomColorPickerSheet(selectedColor: Binding(
                                        get: { CodableColor(color: categoryToEdit.color) },
                                        set: { _ in }
                                    ), showColorPickerSheet: .constant(false)).contrastColor)
                            }
                        }
                        .opacity(categoryToEdit.name.isEmpty ? 0.3 : 1.0)
                    }
                    .disabled(categoryToEdit.name.isEmpty)
                )
                .sheet(isPresented: $showColorPickerSheet) {
                    CustomColorPickerSheet(
                        selectedColor: Binding(
                            get: { CodableColor(color: categoryToEdit.color) },
                            set: { self.categoryToEdit?.color = $0.color }
                        ),
                        showColorPickerSheet: $showColorPickerSheet
                    )
                    .presentationDetents([.fraction(0.4)]) 
                }
                
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCategoryNameFieldFocused = true
            }
        }
    }
}