//
//  GoogleCalendarManager.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/19/24.
//

import Foundation
import GoogleSignIn
import GoogleAPIClientForREST_Calendar

class GoogleCalendarManager: ObservableObject {
    @Published var events: [Event] = []
    @Published var isSignedIn: Bool = false
    private let clientID = "108676165289-ofoumldqk4np020qsac1mqp339n6dok0.apps.googleusercontent.com"
    private let scopes = ["https://www.googleapis.com/auth/calendar"]
    private let service = GTLRCalendarService()
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleSignInCompletion), name: Notification.Name("GoogleSignInCompleted"), object: nil)
    }
    
    @objc func handleSignInCompletion() {
        Task {
            do {
                let fetchedEvents = try await fetchEvents()
                DispatchQueue.main.async {
                    self.events = fetchedEvents
                }
            } catch {
                print("Error fetching events: \(error)")
            }
        }
    }
    
    func signIn(presentingViewController: UIViewController? = nil, completion: @escaping (Error?) -> Void) {
        #if !WIDGET_EXTENSION
        guard let presentingViewController = presentingViewController else {
            print("Error: Presenting view controller is required for sign-in")
            completion(NSError(domain: "GoogleCalendarManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Presenting view controller is required for sign-in"]))
            return
        }
        
        let signInConfig = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = signInConfig
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { signInResult, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            if signInResult != nil {
                self.isSignedIn = true
                NotificationCenter.default.post(name: .googleSignInStateChanged, object: nil)
                completion(nil)
            }
        }
        #else
        print("Google Sign-In is not supported in widget extensions")
        completion(NSError(domain: "GoogleCalendarManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In is not supported in widget extensions"]))
        #endif
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        self.isSignedIn = false
        NotificationCenter.default.post(name: .googleSignInStateChanged, object: nil)
    }
    
    func fetchEvents() async throws -> [Event] {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw NSError(domain: "GoogleCalendarManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            user.refreshTokensIfNeeded { user, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let user = user else {
                    continuation.resume(throwing: NSError(domain: "GoogleCalendarManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "User refresh failed"]))
                    return
                }
                
                self.service.authorizer = user.fetcherAuthorizer
                
                let query = GTLRCalendarQuery_EventsList.query(withCalendarId: "primary")
                query.maxResults = 100
                query.timeMin = GTLRDateTime(date: Date())
                query.singleEvents = true
                query.orderBy = kGTLRCalendarOrderByStartTime
                
                self.service.executeQuery(query) { (ticket, result, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let eventList = result as? GTLRCalendar_Events else {
                        continuation.resume(throwing: NSError(domain: "GoogleCalendarManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid result type"]))
                        return
                    }
                    
                    let events = eventList.items?.compactMap { item -> Event? in
                        guard let title = item.summary,
                              let startDate = item.start?.dateTime?.date ?? item.start?.date?.date,
                              let endDate = item.end?.dateTime?.date ?? item.end?.date?.date else {
                            return nil
                        }
                        
                        return Event(title: title,
                                     date: startDate,
                                     endDate: endDate,
                                     color: CodableColor(color: .blue),
                                     category: "Google Calendar",
                                     isGoogleCalendarEvent: true)
                    } ?? []
                    
                    continuation.resume(returning: events)
                }
            }
        }
    }
    
    func signInAndFetchEvents(presentingViewController: UIViewController? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            signIn(presentingViewController: presentingViewController) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    Task {
                        do {
                            let events = try await self.fetchEvents()
                            DispatchQueue.main.async {
                                self.events = events
                                continuation.resume()
                            }
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
    
    private func addEventsToApp() {
        let appData = AppData.shared
        for event in self.events {
            if !appData.events.contains(where: { $0.title == event.title && $0.date == event.date }) {
                appData.addEvent(event)
            }
        }
    }
    
    func clearEvents() {
        DispatchQueue.main.async {
            self.events.removeAll()
        }
    }
}