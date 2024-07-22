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
    @State private var newCategoryColor: Color
    @FocusState private var isCategoryNameFieldFocused: Bool
    var onSave: ((name: String, color: Color)) -> Void
    @State private var showColorPickerSheet = false
    @State private var selectedColor: CodableColor
    
    init(showingAddCategorySheet: Binding<Bool>, onSave: @escaping ((name: String, color: Color)) -> Void) {
        self._showingAddCategorySheet = showingAddCategorySheet
        self.onSave = onSave
        let randomColor = CustomColorPickerSheet.staticPredefinedColors.randomElement() ?? .blue
        self._selectedColor = State(initialValue: CodableColor(color: randomColor))
        self._newCategoryColor = State(initialValue: randomColor)
    }

    var body: some View {
        Form {
            TextField("Category Name", text: $newCategoryName)
                .focused($isCategoryNameFieldFocused)
            HStack {
                Text("Color")
                Spacer()
                Button(action: {
                    showColorPickerSheet = true
                }) {
                    Circle()
                        .fill(newCategoryColor)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .navigationBarTitle("Add Category", displayMode: .inline)
        .navigationBarItems(
            leading: Button("Cancel") {
                showingAddCategorySheet = false
            },
            trailing: Button(action: {
                onSave((name: newCategoryName, color: selectedColor.color))
                showingAddCategorySheet = false
            }) {
                Group {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedColor.color)
                            .frame(width: 60, height: 32)
                        Text("Save")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .opacity(newCategoryName.isEmpty ? 0.3 : 1.0)
            }
            .disabled(newCategoryName.isEmpty)
        )
        .sheet(isPresented: $showColorPickerSheet) {
            CustomColorPickerSheet(
                selectedColor: $selectedColor,
                showColorPickerSheet: $showColorPickerSheet
            )
            .presentationDetents([.fraction(0.4)]) 
        }
        .onChange(of: selectedColor.color) {
            newCategoryColor = selectedColor.color
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCategoryNameFieldFocused = true
            }
        }
    }
}

extension CodableColor: Equatable {
    static func == (lhs: CodableColor, rhs: CodableColor) -> Bool {
        return lhs.color == rhs.color
    }
}