import SwiftUI
import Charts
import ChessKit

struct ReviewView: View {
    @State var vm: ReviewViewModel
    var onExit: () -> Void

    @State private var showOpeningInfo = false
    @State private var showGlossary = false

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            if vm.loading {
                loadingView
            } else {
                content
            }
        }
        .task { if vm.loading { await vm.load() } }
        .sheet(isPresented: $showOpeningInfo) {
            OpeningInfoView(name: vm.review?.openingName ?? "Opening",
                            moves: Array((vm.review?.moves.prefix(10).map { $0.san }) ?? []))
        }
        .sheet(isPresented: $showGlossary) { ClassificationGlossaryView() }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(Palette.mint)
            Text("Analyzing your game…").font(.chezzTitle2).foregroundStyle(Palette.textPrimary)
            ProgressView(value: vm.progress)
                .tint(Palette.mint)
                .frame(width: 220)
            Text("\(Int(vm.progress * 100))%").font(.chezzCaption).foregroundStyle(Palette.textSecondary)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                header
                if let review = vm.review, review.engineUnavailable { engineBanner }
                accuracyHeader
                if let name = vm.review?.openingName { openingChip(name) }
                evalGraph
                boardSection
                navControls
                coachCard
                moveListSection
                summarySection
                Color.clear.frame(height: Spacing.xl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
    }

    private var header: some View {
        HStack {
            Button(action: onExit) {
                Image(systemName: "chevron.left").font(.headline).foregroundStyle(Palette.textSecondary)
                    .frame(width: 36, height: 36).background(Palette.surface2, in: Circle())
            }
            Spacer()
            Text("Game Review").font(.chezzTitle2).foregroundStyle(Palette.textPrimary)
            Spacer()
            Button { showGlossary = true } label: {
                Image(systemName: "questionmark").font(.headline).foregroundStyle(Palette.textSecondary)
                    .frame(width: 36, height: 36).background(Palette.surface2, in: Circle())
            }
            .accessibilityLabel("What do the move ratings mean?")
        }
    }

    private var engineBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warning)
            Text("Add the Stockfish engine files (run scripts/fetch-nnue.sh) to enable full analysis.")
                .font(.chezzCaption).foregroundStyle(Palette.textSecondary)
        }
        .padding(Spacing.sm).frame(maxWidth: .infinity, alignment: .leading)
        .chezzCard(fill: Palette.surface2, radius: Radius.md)
    }

    private func openingChip(_ name: String) -> some View {
        Button { showOpeningInfo = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "book.fill").font(.caption2)
                Text(name).font(.chezzCallout)
                Image(systemName: "info.circle").font(.caption2)
            }
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, Spacing.sm).padding(.vertical, 6)
            .background(Palette.surface2, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var accuracyHeader: some View {
        HStack(spacing: Spacing.sm) {
            accuracyCard(side: vm.perspective.opposite, name: name(for: vm.perspective.opposite))
            accuracyCard(side: vm.perspective, name: name(for: vm.perspective))
        }
    }

    private func accuracyCard(side: Side, name: String) -> some View {
        let acc = vm.review?.accuracy(for: side)
        let rating = vm.review?.rating(for: side)
        return VStack(spacing: 6) {
            Text(name).font(.chezzCallout).foregroundStyle(Palette.textSecondary).lineLimit(1)
            Text(acc.map { String(format: "%.1f", $0) } ?? "·")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(accuracyColor(acc))
            Text("Accuracy").font(.chezzCaption2).foregroundStyle(Palette.textTertiary)
            if let rating {
                Text("Est. \(rating)").font(.chezzCaption).foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .chezzCard()
    }

    private func accuracyColor(_ acc: Double?) -> Color {
        guard let acc else { return Palette.textSecondary }
        switch acc {
        case 90...: return Palette.mint
        case 80..<90: return Color(hex: "#5FD08A")
        case 65..<80: return Palette.gold
        default: return Palette.warning
        }
    }

    private var evalGraph: some View {
        EvalGraph(series: vm.review?.evalWhitePctSeries ?? [],
                  moves: vm.review?.moves ?? [],
                  currentPly: vm.currentPly,
                  onSelect: { vm.goTo($0) })
            .frame(height: 110)
            .padding(Spacing.sm)
            .chezzCard(fill: Palette.surface, radius: Radius.md)
    }

    private var boardSection: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            EvalBar(whitePct: vm.evalPct, cpWhite: vm.evalCP, mateWhite: vm.evalMate)
                .frame(height: 320)
            BoardView(
                pieces: vm.pieceMap,
                perspective: vm.perspective,
                theme: .midnight,
                selected: nil,
                legalTargets: [],
                lastMove: vm.lastMove,
                checkSquare: vm.checkSquare,
                arrow: vm.bestArrow,
                interactive: false,
                showCoordinates: true
            )
            .overlay(alignment: .topTrailing) { currentBadge }
        }
    }

    @ViewBuilder
    private var currentBadge: some View {
        if let move = vm.currentMove {
            HStack(spacing: 5) {
                ClassificationBadge(classification: move.classification, size: 24)
                Text(move.classification.label).font(.chezzCaption2)
                    .foregroundStyle(ClassificationStyle.color(move.classification))
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(8)
        }
    }

    private var navControls: some View {
        // Each Key button spans the two 40pt arrow buttons + their gap, so the two rows line up.
        let keyWidth: CGFloat = 40 * 2 + Spacing.xs
        return VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                navButton("backward.end.fill") { vm.first() }
                navButton("chevron.backward") { vm.prev() }
                Spacer()
                Text(moveCounter).font(.chezzCallout.monospacedDigit()).foregroundStyle(Palette.textSecondary)
                Spacer()
                navButton("chevron.forward") { vm.next() }
                navButton("forward.end.fill") { vm.last() }
            }
            HStack(spacing: 0) {
                keyButton("Key", leading: true) { vm.prevKeyMoment() }.frame(width: keyWidth)
                Spacer()
                keyButton("Key", leading: false) { vm.nextKeyMoment() }.frame(width: keyWidth)
            }
        }
    }

    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 40, height: 36)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm))
        }
    }
    private func keyButton(_ label: String, leading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if leading { Image(systemName: "chevron.left").font(.caption2) }
                Text(label).font(.chezzCaption)
                if !leading { Image(systemName: "chevron.right").font(.caption2) }
            }
            .foregroundStyle(Palette.mint)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(Palette.mintSoft, in: RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
    }
    private var moveCounter: String {
        vm.currentPly == 0 ? "Start" : "\(vm.currentPly) / \(vm.plyCount)"
    }

    @ViewBuilder
    private var coachCard: some View {
        if let move = vm.currentMove {
            HStack(alignment: .top, spacing: Spacing.sm) {
                ClassificationBadge(classification: move.classification, size: 30)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(move.moveNumber)\(move.color == .white ? "." : "...") \(move.san)")
                            .font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
                        Button { showGlossary = true } label: {
                            HStack(spacing: 3) {
                                Text(move.classification.label).font(.chezzCaption)
                                Image(systemName: "info.circle").font(.system(size: 9))
                            }
                            .foregroundStyle(ClassificationStyle.color(move.classification))
                        }
                        .buttonStyle(.plain)
                    }
                    Text(move.coachText).font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                    if !move.isBest, let best = move.bestMoveSAN {
                        Text("Best: \(best)" + (move.bestLineSANs.count > 1 ? "  " + move.bestLineSANs.prefix(4).joined(separator: " ") : ""))
                            .font(.chezzCaption).foregroundStyle(Palette.mint)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .chezzCard(fill: Palette.surface, radius: Radius.md)
        } else {
            Text("Tap a move or use the arrows to step through the game.")
                .font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md).chezzCard(fill: Palette.surface, radius: Radius.md)
        }
    }

    private var moveListSection: some View {
        let rows = moveRows
        return VStack(spacing: 0) {
            ForEach(rows, id: \.number) { row in
                HStack(spacing: 0) {
                    Text("\(row.number).").font(.chezzCaption.monospacedDigit())
                        .foregroundStyle(Palette.textTertiary).frame(width: 34, alignment: .leading)
                    moveCell(row.white)
                    moveCell(row.black)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 5).padding(.horizontal, Spacing.sm)
                .background(row.number % 2 == 0 ? Color.clear : Palette.surface2.opacity(0.4))
            }
        }
        .chezzCard(fill: Palette.surface, radius: Radius.md)
    }

    @ViewBuilder
    private func moveCell(_ move: MoveReview?) -> some View {
        if let move {
            let isCurrent = vm.currentPly == move.ply + 1
            Button { vm.goTo(move.ply + 1) } label: {
                HStack(spacing: 4) {
                    Text(move.san).font(.chezzCallout)
                        .foregroundStyle(isCurrent ? Palette.canvas : Palette.textPrimary)
                    ClassificationBadge(classification: move.classification, size: 15)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(isCurrent ? Palette.mint : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .frame(width: 110, alignment: .leading)
        } else {
            Color.clear.frame(width: 110, height: 1)
        }
    }

    private struct MoveRow { let number: Int; let white: MoveReview?; let black: MoveReview? }
    private var moveRows: [MoveRow] {
        guard let moves = vm.review?.moves else { return [] }
        var rows: [MoveRow] = []
        var i = 0
        var number = 1
        while i < moves.count {
            let white = moves[i].color == .white ? moves[i] : nil
            var black: MoveReview?
            var advance = 1
            if white != nil, i + 1 < moves.count, moves[i + 1].color == .black { black = moves[i + 1]; advance = 2 }
            else if white == nil { black = moves[i] }
            rows.append(MoveRow(number: number, white: white, black: black))
            number += 1
            i += advance
        }
        return rows
    }

    private var summarySection: some View {
        VStack(spacing: Spacing.sm) {
            Text("Move summary").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .top, spacing: Spacing.lg) {
                summaryColumn(side: vm.perspective, title: name(for: vm.perspective))
                summaryColumn(side: vm.perspective.opposite, title: name(for: vm.perspective.opposite))
            }
        }
        .padding(Spacing.md).chezzCard(fill: Palette.surface, radius: Radius.md)
    }

    private func summaryColumn(side: Side, title: String) -> some View {
        let counts = vm.review?.counts(for: side) ?? [:]
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.chezzCallout).foregroundStyle(Palette.textSecondary)
            ForEach(MoveClassification.allCases, id: \.self) { cls in
                if let n = counts[cls], n > 0 {
                    ClassificationLegendRow(classification: cls, count: n)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func name(for side: Side) -> String { side == .white ? vm.whiteName : vm.blackName }
}

private struct EvalGraph: View {
    let series: [Double]
    let moves: [MoveReview]
    let currentPly: Int
    let onSelect: (Int) -> Void

    @State private var selectedX: Int?

    var body: some View {
        Chart {
            ForEach(Array(series.enumerated()), id: \.offset) { i, v in
                AreaMark(x: .value("Move", i), y: .value("Eval", v))
                    .foregroundStyle(.linearGradient(colors: [Palette.evalWhite.opacity(0.28), Palette.evalWhite.opacity(0.04)],
                                                     startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Move", i), y: .value("Eval", v))
                    .foregroundStyle(Palette.textPrimary.opacity(0.85))
                    .interpolationMethod(.monotone)
            }
            RuleMark(y: .value("Equal", 50))
                .foregroundStyle(Palette.hairline)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            ForEach(notablePoints, id: \.ply) { pt in
                PointMark(x: .value("Move", pt.ply), y: .value("Eval", pt.value))
                    .foregroundStyle(ClassificationStyle.color(pt.cls))
                    .symbolSize(50)
            }
            RuleMark(x: .value("Current", currentPly)).foregroundStyle(Palette.mint.opacity(0.9))
            PointMark(x: .value("Current", currentPly),
                      y: .value("Eval", currentValue))
                .foregroundStyle(Palette.mint).symbolSize(70)
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: 0...max(1, series.count - 1))
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .chartXSelection(value: $selectedX)
        .onChange(of: selectedX) { _, newValue in if let newValue { onSelect(newValue) } }
    }

    private var currentValue: Double {
        guard currentPly < series.count else { return 50 }
        return series[currentPly]
    }

    private struct Pt { let ply: Int; let value: Double; let cls: MoveClassification }
    private var notablePoints: [Pt] {
        moves.compactMap { m in
            guard [.blunder, .mistake, .miss, .brilliant, .great].contains(m.classification),
                  m.ply + 1 < series.count else { return nil }
            return Pt(ply: m.ply + 1, value: series[m.ply + 1], cls: m.classification)
        }
    }
}
