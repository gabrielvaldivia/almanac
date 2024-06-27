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
    @FocusState private var isCategoryNameFieldFocused: Bool  // Add this line

    var body: some View {
        NavigationView {
            List {
                // Categories section 
                ForEach(appData.categories.indices, id: \.self) { index in
                    HStack {
                        TextField("Category Name", text: Binding(
                            get: { 
                                if self.appData.categories.indices.contains(index) {
                                    return self.appData.categories[index].name
                                }
                                return ""
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
                                if self.appData.categories.indices.contains(index) {
                                    return self.appData.categories[index].color
                                }
                                return .clear
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
                Section(header: Text("Default Category")) {
                    Picker("Default Category", selection: Binding(
                        get: { 
                            if let firstCategory = appData.categories.first?.name, appData.defaultCategory.isEmpty {
                                return firstCategory
                            }
                            return appData.defaultCategory
                        },
                        set: { appData.defaultCategory = $0 }
                    )) {
                        ForEach(appData.categories, id: \.name) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                // Notification time section
                Section(header: Text("Notification Time")) {
                    DatePicker("Select Time", selection: $appData.notificationTime, displayedComponents: .hourAndMinute)
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle("Manage Categories", displayMode: .inline)
            .navigationBarItems(leading: EditButton(), trailing: Button(action: {
                showingAddCategorySheet = true
                newCategoryName = ""
                newCategoryColor = Color(red: Double.random(in: 0.1...0.9), green: Double.random(in: 0.1...0.9), blue: Double.random(in: 0.1...0.9))  // Ensure middle range color
            }) {
                Image(systemName: "plus")
            })
            
            // Add Category Sheet
            .sheet(isPresented: $showingAddCategorySheet) {
                NavigationView {
                    Form {
                        TextField("Category Name", text: $newCategoryName)
                            .focused($isCategoryNameFieldFocused)  // Add this line
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
                .onAppear {
                    isCategoryNameFieldFocused = true  
                }
            }
            .onAppear {
                appData.loadCategories()
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
