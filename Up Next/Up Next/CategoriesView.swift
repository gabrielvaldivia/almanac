//
//  CategoriesView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var appData: AppData

    var body: some View {
        NavigationView {
            List {
                ForEach(appData.categories.indices, id: \.self) { index in
                    HStack {
                        TextField("Category Name", text: Binding(
                            get: { 
                                guard self.appData.categories.indices.contains(index) else { return "" }
                                return self.appData.categories[index].name 
                            },
                            set: { 
                                guard self.appData.categories.indices.contains(index) else { return }
                                self.appData.categories[index].name = $0 
                            }
                        ))
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { 
                                guard self.appData.categories.indices.contains(index) else { return .clear }
                                return self.appData.categories[index].color 
                            },
                            set: { 
                                guard self.appData.categories.indices.contains(index) else { return }
                                self.appData.categories[index].color = $0 
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                        .padding(.trailing, 10)
                    }
                }
                .onDelete(perform: removeCategory)
                .onMove(perform: moveCategory)
                
                Section(header: Text("Add New Category")) {
                    Button("Add Category") {
                        // Placeholder for adding a new category
                        // This could open a new view or a dialog to input the category details
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle("Manage Categories", displayMode: .inline)
            .navigationBarItems(leading: EditButton(), trailing: Button("Add") {
                // Placeholder for action to add a new category
                // This could trigger a modal or another view for input
            })
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
