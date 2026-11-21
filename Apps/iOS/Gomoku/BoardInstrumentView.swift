import SwiftUI
import UIKit

private struct VeilBoardTapSurface: UIViewRepresentable {
    let enabled: Bool
    let onTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onTap = onTap
        view.isUserInteractionEnabled = enabled
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: (CGPoint) -> Void

        init(onTap: @escaping (CGPoint) -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let view = recognizer.view else { return }
            onTap(recognizer.location(in: view))
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

struct GomokuBoardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var impactIndex: Int?
    @State private var impactScale: CGFloat = 1
    let state: GomokuState
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    var eclipseThinking = false
    var actualSearchStartedAt: Date? = nil
    var eclipseVisualizationEnabled = false
    var eclipseTraceStore: VeilEclipseSearchTraceStore? = nil
    var eclipseSessionID = ""
    var eclipseBoardTurn = 0
    var eclipseMatchPlaying = true
    /// Optional real C++ completed-depth candidate provider. Only the
    /// developer-authorized teaching path supplies a non-nil value.
    var eclipseTeachingCandidate: (() -> Int?)? = nil
    var eclipseTeachingRootRanks: (() -> [Int])? = nil
    var eclipseTeachingPVPrefix: (() -> [Int])? = nil
    let onMove: (Int) -> Void

    private let starPoints = [48, 56, 112, 168, 176]

    var body: some View {
        VStack(spacing: 11) {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let margin = side * 0.055
                let step = (side - margin * 2) / CGFloat(GomokuState.size - 1)

                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(red: 0.42, green: 0.29, blue: 0.15).opacity(0.46))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 1))

                    gomokuGrid(side: side, margin: margin, step: step)
                        .stroke(Color.white.opacity(0.27), lineWidth: 0.65)

                    ForEach(starPoints, id: \.self) { index in
                        let point = gomokuPoint(index: index, margin: margin, step: step)
                        Circle().fill(Color.white.opacity(0.42)).frame(width: 4.2, height: 4.2).position(point)
                    }

                    // Purely decorative; has NO board data/search scores and
                    // cannot intercept touches or provide a move recommendation.
                    if eclipseThinking && eclipseVisualizationEnabled,
                       let eclipseTraceStore {
                        VeilEclipseBoardThoughtField(
                            isThinking: eclipseThinking,
                            actualSearchStartedAt: actualSearchStartedAt,
                            enabled: eclipseVisualizationEnabled,
                            searchTrace: eclipseTraceStore,
                            sessionID: eclipseSessionID,
                            turn: eclipseBoardTurn,
                            matchPlaying: eclipseMatchPlaying
                        )
                        .frame(width: side, height: side)
                        .allowsHitTesting(false)
                    }

                    // Real native root shortlist in rank order, cap 16.
                    // This is NOT a probability heatmap: ordinal intensity
                    // merely reflects which roots the search considered first.
                    // Rate-limited to the HUD budget; never intercepts touches.
                    if eclipseThinking && eclipseVisualizationEnabled,
                       let ranksProvider = eclipseTeachingRootRanks {
                        TimelineView(.periodic(
                            from: .now, by: ProcessInfo.processInfo.isLowPowerModeEnabled
                                || reduceMotion ? 1.0 : 0.5
                        )) { _ in
                            let ranked = ranksProvider()
                            Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
                                for (rank, index) in ranked.prefix(16).enumerated() {
                                    guard (0..<225).contains(index),
                                          state.value(at: index) == 0 else { continue }
                                    let point = gomokuPoint(
                                        index: index, margin: margin, step: step
                                    )
                                    let intensity = 1.0 - Double(rank) / 16.0
                                    let radius = step * 0.36
                                    let halo = Path(ellipseIn: CGRect(
                                        x: point.x - radius, y: point.y - radius,
                                        width: radius * 2, height: radius * 2
                                    ))
                                    context.fill(halo, with: .color(
                                        VeilTheme.goldBright.opacity(0.08 + 0.35 * intensity)
                                    ))
                                }
                            }
                            .frame(width: side, height: side)
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }

                    // Real, board-replayed native exact-TT principal
                    // variation PREFIX. Every hop is hypothetical, never
                    // presented as a forced win or an actual played stone.
                    if eclipseThinking && eclipseVisualizationEnabled,
                       let pvProvider = eclipseTeachingPVPrefix {
                        TimelineView(.periodic(
                            from: .now, by: ProcessInfo.processInfo.isLowPowerModeEnabled
                                || reduceMotion ? 1.0 : 0.5
                        )) { _ in
                            let pv = pvProvider()
                            Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
                                let verified = Array(pv.prefix(16).filter {
                                    (0..<225).contains($0) && state.value(at: $0) == 0
                                })
                                guard !verified.isEmpty else { return }
                                var path = Path()
                                for (offset, index) in verified.enumerated() {
                                    let point = gomokuPoint(
                                        index: index, margin: margin, step: step
                                    )
                                    if offset == 0 { path.move(to: point) }
                                    else { path.addLine(to: point) }
                                    let radius = step * 0.22
                                    let ring = Path(ellipseIn: CGRect(
                                        x: point.x - radius, y: point.y - radius,
                                        width: radius * 2, height: radius * 2
                                    ))
                                    context.stroke(ring, with: .color(
                                        VeilTheme.paleMetal.opacity(0.9)
                                    ), lineWidth: 1.5)
                                }
                                context.stroke(path, with: .color(
                                    VeilTheme.paleMetal.opacity(0.6)
                                ), style: StrokeStyle(
                                    lineWidth: 1, lineCap: .round, dash: [2, 3]
                                ))
                            }
                            .frame(width: side, height: side)
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }

                    // Lightweight, NON-interactive teaching hint on the
                    // original wood board. The formal match never enables
                    // this provider. Do not invent a best move when C++ has
                    // not completed one full depth.
                    if eclipseThinking && eclipseVisualizationEnabled,
                       let candidateProvider = eclipseTeachingCandidate {
                        TimelineView(.periodic(
                            from: .now, by: ProcessInfo.processInfo.isLowPowerModeEnabled
                                || reduceMotion ? 1.0 : 0.5
                        )) { _ in
                            if let index = candidateProvider(),
                               (0..<225).contains(index),
                               state.value(at: index) == 0 {
                                let point = gomokuPoint(
                                    index: index, margin: margin, step: step
                                )
                                Circle()
                                    .stroke(
                                        VeilTheme.goldBright.opacity(0.85),
                                        style: StrokeStyle(lineWidth: 1.3, dash: [3, 3])
                                    )
                                    .frame(width: step * 0.9, height: step * 0.9)
                                    .position(point)
                                    .accessibilityLabel("教学：完整搜索深度的最佳候选落点")
                            }
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }

                    if state.winningLine.count >= 5,
                       let first = state.winningLine.first,
                       let last = state.winningLine.last {
                        Path { path in
                            path.move(to: gomokuPoint(index: first, margin: margin, step: step))
                            path.addLine(to: gomokuPoint(index: last, margin: margin, step: step))
                        }
                        .stroke(VeilTheme.gold.opacity(0.9), style: StrokeStyle(lineWidth: max(2, step * 0.12), lineCap: .round))
                    }

                    ForEach(0..<(GomokuState.size * GomokuState.size), id: \.self) { index in
                        let value = state.value(at: index)
                        if value != 0 {
                            let point = gomokuPoint(index: index, margin: margin, step: step)
                            Circle()
                                .fill(value == 1 ? Color.black.opacity(0.96) : Color.white.opacity(0.96))
                                .frame(width: step * 0.82, height: step * 0.82)
                                .overlay(
                                    Circle().stroke(state.lastMove == index ? VeilTheme.gold : (value == 1 ? Color.white.opacity(0.16) : Color.black.opacity(0.24)), lineWidth: state.lastMove == index ? 2 : 0.7)
                                )
                                .shadow(color: Color.black.opacity(0.28), radius: 1.4, x: 0, y: 1)
                                .position(point)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    // Original VeilLink R17: a single event-bound impact pulse.
                    // It never displays a candidate move or intercepts a drag.
                    if !eclipseSessionID.isEmpty && !reduceMotion,
                       let index = impactIndex, state.lastMove == index {
                        let center = gomokuPoint(index: index, margin: margin, step: step)
                        Circle()
                            .stroke(VeilTheme.goldBright.opacity(Double(1 - impactScale)), lineWidth: 2)
                            .frame(width: step * (0.7 + 1.5 * impactScale),
                                   height: step * (0.7 + 1.5 * impactScale))
                            .position(center)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    VeilBoardTapSurface(enabled: enabled) { location in
                        guard enabled, step > 0 else { return }
                        let col = Int(round((location.x - margin) / step))
                        let row = Int(round((location.y - margin) / step))
                        guard (0..<GomokuState.size).contains(row), (0..<GomokuState.size).contains(col) else { return }
                        let point = CGPoint(x: margin + CGFloat(col) * step, y: margin + CGFloat(row) * step)
                        let dx = location.x - point.x
                        let dy = location.y - point.y
                        guard hypot(dx, dy) <= step * 0.52 else { return }
                        let index = row * GomokuState.size + col
                        guard state.value(at: index) == 0 else { return }
                        onMove(index)
                    }
                }
                .frame(width: side, height: side)
                .animation(VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion), value: state.moveCount)
                .onChange(of: state.lastMove) { index in
                    guard !eclipseSessionID.isEmpty, !reduceMotion, let index else {
                        impactIndex = nil
                        impactScale = 1
                        return
                    }
                    impactIndex = index
                    impactScale = 0
                    withAnimation(.easeOut(duration: 0.65)) { impactScale = 1 }
                }
            }
            .aspectRatio(1, contentMode: .fit)

            HStack {
                Text(localPlayer == .host ? "你执黑 · 先手" : "你执白 · 后手")
                Spacer()
                Text(enabled ? "轻触交叉点落子" : "等待对方")
            }
            .font(.caption)
            .foregroundColor(enabled ? VeilTheme.gold : VeilTheme.secondaryText)
        }
        .accessibilityRepresentation {
            VStack {
                Text("五子棋棋盘，已进行 \(state.moveCount) 手")
                ForEach(0..<GomokuState.size, id: \.self) { row in
                    HStack {
                        ForEach(0..<GomokuState.size, id: \.self) { col in
                            let index = row * GomokuState.size + col
                            let stone = state.value(at: index)
                            Button("第 \(row + 1) 行，第 \(col + 1) 列，\(stone == 1 ? "黑棋" : stone == 2 ? "白棋" : "空位")") {
                                if enabled && stone == 0 { onMove(index) }
                            }
                            .disabled(!enabled || stone != 0)
                        }
                    }
                }
            }
        }
    }

    private func gomokuPoint(index: Int, margin: CGFloat, step: CGFloat) -> CGPoint {
        CGPoint(x: margin + CGFloat(index % GomokuState.size) * step,
                y: margin + CGFloat(index / GomokuState.size) * step)
    }

    private func gomokuGrid(side: CGFloat, margin: CGFloat, step: CGFloat) -> Path {
        Path { path in
            for value in 0..<GomokuState.size {
                let offset = margin + CGFloat(value) * step
                path.move(to: CGPoint(x: margin, y: offset))
                path.addLine(to: CGPoint(x: side - margin, y: offset))
                path.move(to: CGPoint(x: offset, y: margin))
                path.addLine(to: CGPoint(x: offset, y: side - margin))
            }
        }
    }
}
