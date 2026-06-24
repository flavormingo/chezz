import SwiftUI

struct EvalBar: View {
    var whitePct: Double
    var cpWhite: Double = 0
    var mateWhite: Int?
    var showLabel: Bool = true

    private var clamped: Double { max(2, min(98, whitePct)) }
    private var whiteAhead: Bool { whitePct >= 50 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Rectangle().fill(Palette.evalBlack)
                Rectangle().fill(Palette.evalWhite)
                    .frame(height: geo.size.height * CGFloat(clamped / 100.0))
            }
            .overlay(alignment: whiteAhead ? .bottom : .top) {
                if showLabel {
                    Text(label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(whiteAhead ? Palette.evalBlack : Palette.evalWhite)
                        .padding(.vertical, 3)
                        .fixedSize()
                }
            }
        }
        .frame(width: 18)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 0.5))
    }

    private var label: String {
        if let m = mateWhite, m != 0 { return "M\(abs(m))" }
        // Magnitude only: the bar fill (and label position) already shows which side is ahead.
        return String(format: "%.1f", abs(cpWhite) / 100.0)
    }
}
