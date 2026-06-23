import SwiftUI
import Observation

@MainActor
@Observable
final class AppSettings {
    var boardThemeID: String { didSet { d.set(boardThemeID, forKey: K.boardTheme) } }
    var appThemeID: String {
        didSet {
            d.set(appThemeID, forKey: K.appTheme)
            ThemeHolder.shared.theme = AppTheme.named(appThemeID)
        }
    }
    var hapticsEnabled: Bool { didSet { d.set(hapticsEnabled, forKey: K.haptics) } }
    var soundEnabled: Bool { didSet { d.set(soundEnabled, forKey: K.sound) } }
    var showLegalMoves: Bool { didSet { d.set(showLegalMoves, forKey: K.legal) } }
    var showCoordinates: Bool { didSet { d.set(showCoordinates, forKey: K.coords) } }
    var confirmResign: Bool { didSet { d.set(confirmResign, forKey: K.confirmResign) } }
    var defaultMinutes: Int { didSet { d.set(defaultMinutes, forKey: K.minutes) } }

    var boardTheme: BoardTheme { BoardTheme.named(boardThemeID) }

    private let d = UserDefaults.standard
    private enum K {
        static let boardTheme = "boardThemeID"
        static let appTheme = "appThemeID"
        static let haptics = "hapticsEnabled"
        static let sound = "soundEnabled"
        static let legal = "showLegalMoves"
        static let coords = "showCoordinates"
        static let confirmResign = "confirmResign"
        static let minutes = "defaultMinutes"
    }

    init() {
        boardThemeID = d.string(forKey: K.boardTheme) ?? BoardTheme.wood.id
        appThemeID = d.string(forKey: K.appTheme) ?? AppTheme.default.id
        hapticsEnabled = d.object(forKey: K.haptics) as? Bool ?? true
        soundEnabled = d.object(forKey: K.sound) as? Bool ?? true
        showLegalMoves = d.object(forKey: K.legal) as? Bool ?? true
        showCoordinates = d.object(forKey: K.coords) as? Bool ?? true
        confirmResign = d.object(forKey: K.confirmResign) as? Bool ?? true
        defaultMinutes = d.object(forKey: K.minutes) as? Int ?? 10
        // didSet doesn't fire during init, so sync the theme holder explicitly.
        ThemeHolder.shared.theme = AppTheme.named(appThemeID)
    }
}
