import SwiftUI
import UIKit

// SwiftUI only dismisses the keyboard on Return. This installs ONE window-level tap recognizer so a
// tap outside a field dismisses it everywhere. cancelsTouchesInView = false keeps buttons/controls
// working, and the delegate ignores taps that land on a text input so you can still focus/switch fields.
@MainActor
enum KeyboardDismiss {
    private static let coordinator = Coordinator()
    private static var installed = false

    static func install() {
        guard !installed else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else { return }
        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.dismiss))
        tap.cancelsTouchesInView = false
        tap.delegate = coordinator
        window.addGestureRecognizer(tap)
        installed = true
    }

    private final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @objc func dismiss() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        // Coexist with the board / list / scroll gestures instead of blocking them.
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
        // Don't hijack taps on text inputs, or focusing/switching fields would break.
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let v = view {
                if v is UITextField || v is UITextView { return false }
                view = v.superview
            }
            return true
        }
    }
}
