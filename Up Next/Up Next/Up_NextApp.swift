//
//  Up_NextApp.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import SwiftUI

@main
struct Up_NextApp: App {
    @StateObject private var appData = AppData.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Perform any necessary updates when the app becomes active
            }
        }
    }
}