import Foundation
@preconcurrency import Contacts

enum ContactsService {
    static var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    static func requestAndFetchE164() async throws -> [String] {
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
                            if let e = e164(pn.value.stringValue) { numbers.insert(e) }
                        }
                    }
                    cont.resume(returning: Array(numbers))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    // Best-effort; assumes +1 (US/CA) when no country code is present.
    static func e164(_ raw: String, defaultCountryCode: String = "1") -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        if trimmed.hasPrefix("+") { return "+" + digits }
        if digits.count == 10 { return "+\(defaultCountryCode)\(digits)" }
        if digits.count == 11, digits.hasPrefix("1") { return "+\(digits)" }
        return "+\(digits)"
    }
}
