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
    var category: String

    init() { category = "All Categories" }

    static var parameterSummary: some ParameterSummary {
        Summary("Show events for \(\.$category)") {
            \.$category
        }
    }

    static var options: [String] {
        var categories = ["All Categories"]
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "categories"),
           let decoded = try? JSONDecoder().decode([CategoryData].self, from: data) {
            categories.append(contentsOf: decoded.map { $0.name })
        }
        return categories
    }
}

struct CategoryOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] { ConfigurationAppIntent.options }
}
