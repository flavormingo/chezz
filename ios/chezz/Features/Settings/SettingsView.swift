import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        List {
            Section("Appearance") {
                // .id on the active theme forces both pickers to re-render when the accent changes,
                // so their value text recolors immediately (SwiftUI otherwise caches the tint until
                // the view is rebuilt, e.g. by leaving and returning to Settings).
                Picker("Theme", selection: $settings.appThemeID) {
                    ForEach(AppTheme.all) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .id(settings.appThemeID)
                Picker("Board", selection: $settings.boardThemeID) {
                    ForEach(BoardTheme.all) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .id(settings.appThemeID)
                Toggle("Show legal moves", isOn: $settings.showLegalMoves)
                Toggle("Show coordinates", isOn: $settings.showCoordinates)
            }
            .listRowBackground(Palette.surface)

            Section("Feedback") {
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
                Toggle("Sounds", isOn: $settings.soundEnabled)
            }
            .listRowBackground(Palette.surface)

            Section("Game") {
                Toggle("Confirm resignation", isOn: $settings.confirmResign)
                Stepper("Default time: \(settings.defaultMinutes) min",
                        value: $settings.defaultMinutes, in: 1...60)
            }
            .listRowBackground(Palette.surface)

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Engine", value: "Stockfish 17")
                Text("Chezz is open source under the GNU GPL v3. It uses the Stockfish engine for AI play and analysis.")
                    .font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                Text("Piece icons by iconicFonts/chess-icons (MIT License).")
                    .font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                Text("Made with love by mazz.digital")
                    .font(.chezzCaption).foregroundStyle(Palette.textSecondary)
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .navigationTitle("Settings")
        .tint(Palette.mint)
    }
}
