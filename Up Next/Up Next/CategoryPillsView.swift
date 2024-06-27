//
//  CategoryPillsView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/27/24.
//

import SwiftUI

@ViewBuilder
func CategoryPillsView(appData: AppData, events: [Event], selectedCategoryFilter: Binding<String?>, colorScheme: ColorScheme) -> some View {
    let filteredCategories = appData.categories.filter { category in
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return events.contains { event in
            event.category == category.name && event.date >= startOfToday
        }
    }
    
    if filteredCategories.count > 1 {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(filteredCategories, id: \.name) { category in
                    Button(action: {
                        selectedCategoryFilter.wrappedValue = selectedCategoryFilter.wrappedValue == category.name ? nil : category.name
                    }) {
                        Text(category.name)
                            .font(.footnote)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedCategoryFilter.wrappedValue == category.name ? category.color : Color.clear)
                            .foregroundColor(selectedCategoryFilter.wrappedValue == category.name ? .white : (colorScheme == .dark ? .white : .black))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedCategoryFilter.wrappedValue == category.name ? Color.clear : Color.gray, lineWidth: 1)
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
