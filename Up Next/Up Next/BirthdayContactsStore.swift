import Contacts
import Foundation

struct BirthdayContactsSnapshot: Sendable {
    var birthdays: [ContactBirthday]
    var isLimited: Bool
    var unreadableBirthdayCount = 0
}

enum BirthdayContactsAccess: Sendable {
    case notDetermined, denied, restricted, allowed
}

enum BirthdayContactsStore {
    static var access: BirthdayContactsAccess {
        #if DEBUG
        if testSnapshot != nil { return .allowed }
        #endif
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .authorized: return .allowed
        default:
            if #available(iOS 18, *), CNContactStore.authorizationStatus(for: .contacts) == .limited {
                return .allowed
            }
            return .denied
        }
    }

    static func requestAccess() async throws {
        _ = try await CNContactStore().requestAccess(for: .contacts)
    }

    static func load() async throws -> BirthdayContactsSnapshot {
        #if DEBUG
        if let testSnapshot { return testSnapshot }
        #endif
        // CNContactStore enumeration is synchronous; never block the main thread with it.
        return try await Task.detached(priority: .userInitiated) {
            let store = CNContactStore()
            let keys = [CNContactIdentifierKey as CNKeyDescriptor,
                        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                        CNContactNicknameKey as CNKeyDescriptor,
                        CNContactBirthdayKey as CNKeyDescriptor,
                        CNContactNonGregorianBirthdayKey as CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.unifyResults = true
            var birthdays: [ContactBirthday] = []
            var unreadable = 0
            try store.enumerateContacts(with: request) { contact, _ in
                guard let components = contact.birthday ?? contact.nonGregorianBirthday else { return }
                let formattedName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
                let name = formattedName.isEmpty ? contact.nickname : formattedName
                let identifier: Calendar.Identifier = contact.birthday != nil
                    ? .gregorian : (components.calendar?.identifier ?? .gregorian)
                if let birthday = ContactBirthday(id: contact.identifier, name: name.isEmpty ? "Unnamed Contact" : name,
                                                  birthday: components, calendarIdentifier: identifier) {
                    birthdays.append(birthday)
                } else { unreadable += 1 }
            }
            var limited = false
            if #available(iOS 18, *) { limited = CNContactStore.authorizationStatus(for: .contacts) == .limited }
            return BirthdayContactsSnapshot(birthdays: birthdays.sorted {
                let comparison = $0.name.localizedStandardCompare($1.name)
                return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
            }, isLimited: limited, unreadableBirthdayCount: unreadable)
        }.value
    }

    #if DEBUG
    // Deterministic UI fixtures, available only in debug builds and never saved without review.
    private static var testSnapshot: BirthdayContactsSnapshot? {
        guard ProcessInfo.processInfo.arguments.contains("--birthday-import-ui-test") else { return nil }
        let components = Calendar.current.dateComponents([.month, .day], from: Date())
        return BirthdayContactsSnapshot(birthdays: [
            ContactBirthday(id: "birthday-ui-alex", name: "Birthday Test Alex", birthday: components)!,
            ContactBirthday(id: "birthday-ui-sam", name: "Birthday Test Sam", birthday: components)!
        ], isLimited: false)
    }
    #endif
}
