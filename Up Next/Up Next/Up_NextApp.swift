//
//  Up_NextApp.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import SwiftUI
import UserNotifications
import GoogleSignIn

@main
struct Up_NextApp: App {
    var appData = AppData()
    @StateObject private var googleCalendarManager = GoogleCalendarManager()

    init() {
        requestNotificationPermissions()
        UNUserNotificationCenter.current().delegate = appData
        setupGoogleSignInObserver()
        
        // Initialize Google Sign-In
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                print("Error restoring previous sign-in: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
                .environmentObject(googleCalendarManager)
        }
    }

    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            } else {
                print("Notification permissions granted: \(granted)")
            }
        }
    }

    func setupGoogleSignInObserver() {
        NotificationCenter.default.addObserver(forName: Notification.Name("GoogleSignInRequired"), object: nil, queue: .main) { _ in
            self.handleGoogleSignIn()
        }
    }

    func handleGoogleSignIn() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            print("GIDClientID not set in Info.plist")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
            return
        }
        
        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/calendar"]
        ) { signInResult, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            guard let signInResult = signInResult else { return }
            
            // Store authentication information in shared UserDefaults
            if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") {
                // Store necessary authentication information
                // Be careful not to store sensitive information like tokens
                sharedDefaults.set(signInResult.user.profile?.email, forKey: "GoogleSignInEmail")
                sharedDefaults.set(true, forKey: "IsGoogleSignedIn")
            }
            
            // Notify the GoogleCalendarManager to fetch events
            NotificationCenter.default.post(name: Notification.Name("GoogleSignInCompleted"), object: nil)
        }
    }
}