import SwiftUI
import ChessKit

struct BoardView: View {
    let pieces: [Square: Piece]
    var perspective: Side = .white
    var theme: BoardTheme = .midnight
    var selected: Square?
    var legalTargets: Set<Square> = []
    var lastMove: (from: Square, to: Square)?
    var checkSquare: Square?
    var arrow: (from: Square, to: Square)?
    var interactive: Bool = true
    var showCoordinates: Bool = true

    var canMoveFrom: (Square) -> Bool = { _ in true }
    var onSelect: (Square) -> Void = { _ in }
    var onTap: (Square) -> Void = { _ in }
    var onMove: (Square, Square) -> Void = { _, _ in }

    @State private var dragOrigin: Square?
    @State private var dragLocation: CGPoint?
    @State private var dragTarget: Square?

    private let files = ["a", "b", "c", "d", "e", "f", "g", "h"]

    var body: some View {
        GeometryReader { geo in
            let boardSide = min(geo.size.width, geo.size.height)
            let cell = boardSide / 8

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { col in
                                cellView(row: row, col: col, cell: cell)
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
                .frame(width: boardSide, height: boardSide)

                if let arrow {
                    BestMoveArrow(from: center(arrow.from, cell: cell), to: center(arrow.to, cell: cell), cell: cell)
                        .frame(width: boardSide, height: boardSide)
                        .allowsHitTesting(false)
                }

                if let dragOrigin, let dragLocation, let p = pieces[dragOrigin] {
                    PieceView(piece: p, size: cell * 1.18)
                        .position(dragLocation)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: boardSide, height: boardSide)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(interactive ? drag(cell: cell) : nil)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("chessboard")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func cellView(row: Int, col: Int, cell: CGFloat) -> some View {
        let sq = square(row: row, col: col)
        let isLight = sq.color == .light
        ZStack {
            Rectangle().fill(theme.color(isLight: isLight))

            if lastMove?.from == sq || lastMove?.to == sq {
                Rectangle().fill(BoardStyle.lastMove)
            }
            if selected == sq || dragOrigin == sq {
                Rectangle().fill(BoardStyle.selected)
            }
            if dragTarget == sq, dragOrigin != nil {
                Rectangle().strokeBorder(Palette.mint.opacity(0.9), lineWidth: cell * 0.06)
            }
            if checkSquare == sq {
                Circle()
                    .fill(RadialGradient(colors: [BoardStyle.checkGlow.opacity(0.85), .clear],
                                         center: .center, startRadius: 0, endRadius: cell * 0.7))
            }

            if showCoordinates {
                coordinates(row: row, col: col, isLight: isLight, cell: cell)
            }

            if let p = pieces[sq], dragOrigin != sq {
                PieceView(piece: p, size: cell)
            }

            if legalTargets.contains(sq) {
                if pieces[sq] == nil {
                    Circle().fill(BoardStyle.legalDot.opacity(0.85))
                        .frame(width: cell * 0.32, height: cell * 0.32)
                } else {
                    Circle().strokeBorder(BoardStyle.legalRing.opacity(0.9), lineWidth: cell * 0.09)
                        .frame(width: cell * 0.9, height: cell * 0.9)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityIdentifier("sq-\(sq.notation)")
        .accessibilityLabel(pieces[sq].map { "\($0.color.fullName) \($0.kind) on \(sq.notation)" } ?? sq.notation)
    }

    @ViewBuilder
    private func coordinates(row: Int, col: Int, isLight: Bool, cell: CGFloat) -> some View {
        let labelColor = (isLight ? Color.black : Color.white).opacity(0.5)
        ZStack {
            if col == 0 {
                Text("\(rankLabel(row: row))")
                    .font(.system(size: cell * 0.18, weight: .bold))
                    .foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(2)
            }
            if row == 7 {
                Text(fileLabel(col: col))
                    .font(.system(size: cell * 0.18, weight: .bold))
                    .foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(2)
            }
        }
    }

    private func drag(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = squareAt(value.startLocation, cell: cell)
                if dragOrigin == nil, pieces[start] != nil, canMoveFrom(start) {
                    dragOrigin = start
                    onSelect(start)
                }
                dragLocation = value.location
                dragTarget = squareAt(value.location, cell: cell)
            }
            .onEnded { value in
                let start = squareAt(value.startLocation, cell: cell)
                let end = squareAt(value.location, cell: cell)
                if start == end {
                    onTap(start)
                } else if dragOrigin != nil {
                    onMove(dragOrigin!, end)
                } else {
                    onTap(end)
                }
                dragOrigin = nil
                dragLocation = nil
                dragTarget = nil
            }
    }

    private func square(row: Int, col: Int) -> Square {
        let fileIndex = perspective == .white ? col : (7 - col)
        let rankIndex = perspective == .white ? (7 - row) : row
        return Square("\(files[fileIndex])\(rankIndex + 1)")
    }

    private func squareAt(_ point: CGPoint, cell: CGFloat) -> Square {
        let col = min(7, max(0, Int(point.x / cell)))
        let row = min(7, max(0, Int(point.y / cell)))
        return square(row: row, col: col)
    }

    private func center(_ sq: Square, cell: CGFloat) -> CGPoint {
        let fileIndex = sq.file.number - 1
        let rankIndex = sq.rank.value - 1
        let col = perspective == .white ? fileIndex : (7 - fileIndex)
        let row = perspective == .white ? (7 - rankIndex) : rankIndex
        return CGPoint(x: CGFloat(col) * cell + cell / 2, y: CGFloat(row) * cell + cell / 2)
    }

    private func rankLabel(row: Int) -> Int { perspective == .white ? (8 - row) : (row + 1) }
    private func fileLabel(col: Int) -> String { files[perspective == .white ? col : (7 - col)] }
}

private struct BestMoveArrow: View {
    let from: CGPoint
    let to: CGPoint
    let cell: CGFloat

    var body: some View {
        Path { p in
            let angle = atan2(to.y - from.y, to.x - from.x)
            let headLength = cell * 0.36
            let shaftEnd = CGPoint(x: to.x - cos(angle) * headLength * 0.7,
                                   y: to.y - sin(angle) * headLength * 0.7)
            p.move(to: from)
            p.addLine(to: shaftEnd)
        }
        .stroke(Palette.mint.opacity(0.85), style: StrokeStyle(lineWidth: cell * 0.16, lineCap: .round))
        .overlay(arrowHead)
    }

    private var arrowHead: some View {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLength = cell * 0.36
        let headWidth = cell * 0.28
        let base = CGPoint(x: to.x - cos(angle) * headLength, y: to.y - sin(angle) * headLength)
        let left = CGPoint(x: base.x + cos(angle + .pi / 2) * headWidth / 2,
                           y: base.y + sin(angle + .pi / 2) * headWidth / 2)
        let right = CGPoint(x: base.x + cos(angle - .pi / 2) * headWidth / 2,
                            y: base.y + sin(angle - .pi / 2) * headWidth / 2)
        return Path { p in
            p.move(to: to); p.addLine(to: left); p.addLine(to: right); p.closeSubpath()
        }
        .fill(Palette.mint.opacity(0.9))
    }
}
