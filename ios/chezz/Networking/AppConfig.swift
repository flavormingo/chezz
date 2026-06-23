import Foundation

enum AppConfig {
    static let apiBaseURL = URL(string: "https://api.chezz.lol")!

    static var webSocketURL: URL {
        var comps = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false)!
        comps.scheme = (comps.scheme == "https") ? "wss" : "ws"
        comps.path = "/ws"
        return comps.url!
    }
}
