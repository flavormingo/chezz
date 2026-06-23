import SwiftUI

struct Avatar: View {
    let name: String
    var colorHex: String = "#34E5A1"
    var size: CGFloat = 40
    var isBot: Bool = false
    var imageURL: URL? = nil

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(colors: [Color(hex: colorHex), Color(hex: colorHex).opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing))
            if isBot {
                Image(systemName: "cpu.fill")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Palette.canvas)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.canvas)
            }
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}
