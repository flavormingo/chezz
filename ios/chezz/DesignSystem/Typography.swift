import SwiftUI

extension Font {
    static let chezzTitle      = Font.system(size: 26, weight: .bold, design: .rounded)
    static let chezzTitle2     = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let chezzHeadline   = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let chezzBody       = Font.system(size: 16, weight: .regular)
    static let chezzCallout    = Font.system(size: 15, weight: .medium)
    static let chezzSubhead     = Font.system(size: 14, weight: .medium)
    static let chezzCaption    = Font.system(size: 12, weight: .medium)
    static let chezzCaption2   = Font.system(size: 11, weight: .semibold)

    static func chezzClock(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }
}
