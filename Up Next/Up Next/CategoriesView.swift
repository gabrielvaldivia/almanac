//
//  CategoriesView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import UIKit  // Ensure UIKit is imported for UIColor

extension Color {
    func toHex() -> String? {
        let components = UIColor(self).cgColor.components
        let r: CGFloat = components?[0] ?? 0
        let g: CGFloat = components?[1] ?? 0
        let b: CGFloat = components?[2] ?? 0
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}

struct CategoriesView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingAddCategorySheet = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = Color.blue  // Default color for new category

    var body: some View {
        NavigationView {
            List {
                // Categories section 
                ForEach(appData.categories.indices, id: \.self) { index in
                    HStack {
                        TextField("Category Name", text: Binding(
                            get: { 
                                self.appData.categories.indices.contains(index) ? self.appData.categories[index].name : ""
                            },
                            set: { 
                                if self.appData.categories.indices.contains(index) {
                                    self.appData.categories[index].name = $0
                                }
                            }
                        ))
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { 
                                self.appData.categories.indices.contains(index) ? self.appData.categories[index].color : .clear
                            },
                            set: { 
                                if self.appData.categories.indices.contains(index) {
                                    self.appData.categories[index].color = $0
                                }
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                        .padding(.trailing, 10)
                    }
                }
                .onDelete(perform: removeCategory)
                .onMove(perform: moveCategory)
                
                // Default category section
                // Section() {
                //     Picker("Default Category", selection: $appData.defaultCategory) {
                //         ForEach(appData.categories, id: \.name) { category in
                //             Text(category.name).tag(category.name)
                //         }
                //     }
                //     .pickerStyle(MenuPickerStyle())
                // }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle("Manage Categories", displayMode: .inline)
            .navigationBarItems(leading: EditButton(), trailing: Button(action: {
                showingAddCategorySheet = true
                newCategoryName = ""
                newCategoryColor = Color(red: Double.random(in: 0...1), green: Double.random(in: 0...1), blue: Double.random(in: 0...1))
            }) {
                Image(systemName: "plus")
            })
            .sheet(isPresented: $showingAddCategorySheet) {
                NavigationView {
                    Form {
                        TextField("Category Name", text: $newCategoryName)
                        ColorPicker("Choose Color", selection: $newCategoryColor)
                    }
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingAddCategorySheet = false
                        },
                        trailing: Button("Save") {
                            let newCategory = (name: newCategoryName, color: newCategoryColor)
                            appData.categories.append(newCategory)
                            showingAddCategorySheet = false
                        }
                    )
                }
            }
            .onAppear {
                if appData.defaultCategory.isEmpty, let firstCategory = appData.categories.first?.name {
                    appData.defaultCategory = firstCategory
                }
            }
        }
    }

    private func removeCategory(at offsets: IndexSet) {
        // Ensure UI updates are performed on the main thread
        DispatchQueue.main.async {
            // Safely unwrap and ensure the index is within the range before removing
            if let index = offsets.first, index < self.appData.categories.count {
                self.appData.categories.remove(at: index)
            }
        }
    }

    private func moveCategory(from source: IndexSet, to destination: Int) {
        appData.categories.move(fromOffsets: source, toOffset: destination)
    }
}
