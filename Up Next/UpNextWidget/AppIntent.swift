//
//  AppIntent.swift
//  UpNextWidget
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Choose which category appears in this widget.")

    @Parameter(title: "Category", optionsProvider: CategoryOptionsProvider())
    var category: String?

    init() { category = "All Categories" }

    static var parameterSummary: some ParameterSummary {
        Summary("Show events for \(\.$category)") {
            \.$category
        }
    }

}

struct CategoryOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<String> {
        let categories = AppPreferences.shared.data(forKey: "categories").flatMap { try? CategoryStorage.decode($0) } ?? []
        let items = [IntentItem("All Categories", title: "All Categories")] + categories.map {
            IntentItem(CategoryStorage.widgetSelection(for: $0), title: "\($0.name)")
        }
        return IntentItemCollection(sections: [IntentItemSection(items: items)])
    }
}
