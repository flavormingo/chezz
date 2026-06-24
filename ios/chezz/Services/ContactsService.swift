import Foundation
@preconcurrency import Contacts

enum ContactsService {
    static var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    // Raw phone strings straight from the address book. The server normalizes each to E.164 using the
    // caller's region, so any format works ("(415) 555-2671", "+1 415...", "07911 123456"); doing it
    // server-side with libphonenumber is far more accurate than guessing +1 on-device.
    static func requestAndFetchNumbers() async throws -> [String] {
        let store = CNContactStore()
        let granted: Bool = await withCheckedContinuation { cont in
            store.requestAccess(for: .contacts) { ok, _ in cont.resume(returning: ok) }
        }
        guard granted else { throw APIError(code: "contacts_denied", message: "Contacts access was denied.") }

        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
                    let request = CNContactFetchRequest(keysToFetch: keys)
                    var numbers = Set<String>()
                    try store.enumerateContacts(with: request) { contact, _ in
                        for pn in contact.phoneNumbers {
                            let s = pn.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !s.isEmpty { numbers.insert(s) }
                        }
                    }
                    cont.resume(returning: Array(numbers))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    // The device's region (e.g. "US"), used as the default country for national-format numbers.
    static var region: String? { Locale.current.region?.identifier }
}
