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

    let predefinedColors: [Color] = [
        .primary, .gray, .red, .green, .blue, .orange, .pink, .purple, .indigo, .mint, .teal, .cyan, .brown
    ]

    var body: some View {
        Form {
            TextField("Category Name", text: $newCategoryName)
                .focused($isCategoryNameFieldFocused)
            HStack {
                Text("Color")
                Spacer()
                Menu {
                    ForEach(predefinedColors, id: \.self) { color in
                        Button(action: {
                            newCategoryColor = color
                        }) {
                            HStack {
                                Circle()
                                    .fill(color)
                                    .frame(width: 20, height: 20)
                                Text(color.description.capitalized)
                            }
                        }
                    }
                } label: {
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
            trailing: Button("Save") {
                onSave((name: newCategoryName, color: newCategoryColor))
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