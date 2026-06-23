import Foundation

struct APIError: Error, LocalizedError {
    let code: String
    let message: String
    var errorDescription: String? { message }
}

private struct APIErrorEnvelope: Decodable {
    struct Inner: Decodable { let code: String; let message: String }
    let error: Inner
}

private struct BetterAuthErrorBody: Decodable {
    let message: String?
    let code: String?
}

actor APIClient {
    static let shared = APIClient()

    private let base = AppConfig.apiBaseURL
    private let session: URLSession
    private(set) var token: String?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.waitsForConnectivity = false
        // Bearer-only auth, never cookies: if URLSession replays BetterAuth's Set-Cookie, the server
        // enforces a CSRF origin check a native client can't satisfy ("Missing or null Origin").
        cfg.httpShouldSetCookies = false
        cfg.httpCookieAcceptPolicy = .never
        cfg.httpCookieStorage = nil
        session = URLSession(configuration: cfg)
        token = Keychain.get(Keychain.tokenKey)
    }

    var hasToken: Bool { token != nil }

    func setToken(_ newToken: String?) {
        token = newToken
        if let newToken { Keychain.set(newToken, for: Keychain.tokenKey) }
        else { Keychain.delete(Keychain.tokenKey) }
    }

    var bearerToken: String? { token }

    @discardableResult
    private func send(_ path: String, method: String, body: Data?) async throws -> Data {
        guard let url = URL(string: base.absoluteString + path) else {
            throw APIError(code: "bad_url", message: "Invalid URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError(code: "network", message: "No connection. Check your internet and try again.")
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError(code: "no_http", message: "Couldn't reach the server.")
        }
        if let t = http.value(forHTTPHeaderField: "set-auth-token"), !t.isEmpty { setToken(t) }

        guard (200..<300).contains(http.statusCode) else {
            throw friendlyError(status: http.statusCode, data: data)
        }
        return data
    }

    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        try decode(try await send(path, method: "GET", body: nil))
    }

    func post<T: Decodable>(_ path: String, body: (some Encodable)? = Optional<Empty>.none, as type: T.Type) async throws -> T {
        let data = try body.map { try encoder.encode($0) } ?? Data("{}".utf8)
        return try decode(try await send(path, method: "POST", body: data))
    }

    func postVoid(_ path: String, body: (some Encodable)? = Optional<Empty>.none) async throws {
        let data = try body.map { try encoder.encode($0) } ?? Data("{}".utf8)
        _ = try await send(path, method: "POST", body: data)
    }

    func patch<T: Decodable>(_ path: String, body: some Encodable, as type: T.Type) async throws -> T {
        try decode(try await send(path, method: "PATCH", body: try encoder.encode(body)))
    }

    func deleteVoid(_ path: String) async throws {
        _ = try await send(path, method: "DELETE", body: nil)
    }

    func uploadAvatar(_ jpeg: Data) async throws -> ProfileDTO {
        guard let url = URL(string: base.absoluteString + "/api/v1/me/avatar") else {
            throw APIError(code: "bad_url", message: "Invalid URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = jpeg

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: req) }
        catch { throw APIError(code: "network", message: "No connection. Check your internet and try again.") }
        guard let http = response as? HTTPURLResponse else {
            throw APIError(code: "no_http", message: "Couldn't reach the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw friendlyError(status: http.statusCode, data: data)
        }
        return try decode(data)
    }

    func removeAvatar() async throws -> ProfileDTO {
        try decode(try await send("/api/v1/me/avatar", method: "DELETE", body: nil))
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError(code: "decode", message: "Something went wrong. Please try again.") }
    }

    private func friendlyError(status: Int, data: Data) -> APIError {
        var serverCode: String?
        var serverMessage: String?
        if let env = try? decoder.decode(APIErrorEnvelope.self, from: data) {
            serverCode = env.error.code
            serverMessage = env.error.message
        } else if let ba = try? decoder.decode(BetterAuthErrorBody.self, from: data) {
            serverCode = ba.code
            serverMessage = ba.message
        }
        return APIError(code: "http_\(status)",
                        message: Self.friendlyMessage(status: status, code: serverCode, server: serverMessage))
    }

    private static let shortMessages: [String: String] = [
        "username_taken": "That username is taken.",
        "USERNAME_IS_ALREADY_TAKEN": "That username is taken.",
        "invalid_username": "Usernames are 3-20 letters, numbers, _ or .",
        "phone_in_use": "That number is already linked to an account.",
        "invalid_phone": "Enter a valid phone number.",
        "not_friends": "You can only challenge friends.",
        "too_large": "That image is too large (max 2 MB).",
        "bad_type": "Use a JPEG or PNG image.",
        "INVALID_OTP": "Wrong or expired code.",
        "OTP_EXPIRED": "That code has expired.",
        "INVALID_EMAIL": "Enter a valid email.",
        "MISSING_OR_NULL_ORIGIN": "Please update the app and try again.",
    ]

    private static func friendlyMessage(status: Int, code: String?, server: String?) -> String {
        if let code, let mapped = shortMessages[code] { return mapped }
        switch status {
        case 429: return "Too many attempts. Try again in a minute."
        case 401: return "Please sign in again."
        case 413: return "That image is too large (max 2 MB)."
        case 408: return "Request timed out. Try again."
        case 500...: return "Something went wrong. Please try again."
        default: break
        }
        if let server = server?.trimmingCharacters(in: .whitespacesAndNewlines), !server.isEmpty {
            return server
        }
        switch status {
        case 403: return "You don't have access to that."
        case 404: return "Not found."
        default: return "Something went wrong. Please try again."
        }
    }
}

struct Empty: Codable {}
