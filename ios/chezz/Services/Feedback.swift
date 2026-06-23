import UIKit
import AudioToolbox

@MainActor
enum Feedback {
    enum Event {
        case move, capture, castle, check, promote, gameEnd, illegal, select
    }

    static func play(_ event: Event, haptics: Bool, sound: Bool) {
        if haptics { haptic(event) }
        if sound { systemSound(event) }
    }

    private static func haptic(_ event: Event) {
        switch event {
        case .move, .select:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .capture, .castle, .promote:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .check:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.9)
        case .gameEnd:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .illegal:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private static func systemSound(_ event: Event) {
        switch event {
        case .move, .select: AudioServicesPlaySystemSound(1104)
        case .capture, .castle, .promote, .check: AudioServicesPlaySystemSound(1105)
        case .gameEnd: AudioServicesPlaySystemSound(1325)
        case .illegal: AudioServicesPlaySystemSound(1053)
        }
    }
}
