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
    @ObservedObject private var appearance = VeilAppearanceController.shared
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
    let onMove: (Int) -> Void

    private let starPoints = [48, 56, 112, 168, 176]

    var body: some View {
        VStack(spacing: 11) {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let dark = appearance.isDarkAppearance
                let margin = side * 0.055
                let step = (side - margin * 2) / CGFloat(GomokuState.size - 1)

                ZStack {
                    // One fixed-cost material surface, never 225 animated
                    // layers. Gold, wood and glass invert with the theme.
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: dark
                                    ? [Color(red: 0.34, green: 0.24, blue: 0.16),
                                       Color(red: 0.19, green: 0.14, blue: 0.105)]
                                    : [Color(red: 0.90, green: 0.80, blue: 0.63),
                                       Color(red: 0.77, green: 0.64, blue: 0.46)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    dark ? VeilTheme.gold.opacity(0.42)
                                         : Color.black.opacity(0.23),
                                    lineWidth: 1.1
                                )
                        )
                        .overlay(
                            VeilMachinedRim(cornerRadius: 12, width: 2.1)
                        )
                        // The bronze face is set into a flush-machined chassis.
                        // Both highlight rails remain inside existing bounds.
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(
                                    dark ? Color.black.opacity(0.55)
                                         : Color.white.opacity(0.56),
                                    lineWidth: 1.5
                                )
                                .padding(6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    dark ? VeilTheme.gold.opacity(0.13)
                                         : Color.black.opacity(0.10),
                                    lineWidth: 0.65
                                )
                                .padding(9)
                        )

                    gomokuGrid(side: side, margin: margin, step: step)
                        .stroke(
                            dark ? Color.white.opacity(0.26)
                                 : Color.black.opacity(0.40),
                            lineWidth: 0.75
                        )

                    ForEach(starPoints, id: \.self) { index in
                        let point = gomokuPoint(index: index, margin: margin, step: step)
                        Circle()
                            .fill(dark ? Color.white.opacity(0.53)
                                       : Color.black.opacity(0.44))
                            .frame(width: 4.2, height: 4.2)
                            .position(point)
                    }
                    // Four recessed fastening points sit OUTSIDE the grid.
                    // They are decorative and under the native tap surface.
                    ForEach(0..<4, id: \.self) { corner in
                        let farX = corner % 2 == 1
                        let farY = corner >= 2
                        VeilMachinedRivet(diameter: max(6.5, min(9, side * 0.024)))
                            .position(
                                x: side * (farX ? 0.973 : 0.027),
                                y: side * (farY ? 0.973 : 0.027)
                            )
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
                                .fill(
                                    RadialGradient(
                                        colors: value == 1
                                            ? [Color(white: 0.25), Color(white: 0.035)]
                                            : [Color.white, Color(white: 0.80)],
                                        center: UnitPoint(x: 0.32, y: 0.22),
                                        startRadius: 0,
                                        endRadius: max(8, step * 0.9)
                                    )
                                )
                                .frame(width: step * 0.82, height: step * 0.82)
                                .overlay(
                                    Circle().stroke(state.lastMove == index ? VeilTheme.gold : (value == 1 ? Color.white.opacity(0.16) : Color.black.opacity(0.24)), lineWidth: state.lastMove == index ? 2 : 0.7)
                                )
                                .shadow(color: Color.black.opacity(0.28), radius: 1.4, x: 0, y: 1)
                                .position(point)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    // The precise mark belongs only to an ACTUALLY placed
                    // stone. It never hints where the user should play next.
                    if let last = state.lastMove, state.value(at: last) != 0 {
                        Circle()
                            .fill(VeilTheme.goldBright)
                            .frame(width: max(2.8, step * 0.16),
                                   height: max(2.8, step * 0.16))
                            .position(gomokuPoint(index: last, margin: margin, step: step))
                            .allowsHitTesting(false)
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
                Text(enabled ? "轻触交叉点落子" :
                     eclipseThinking ? "ECLIPSE 正在分析" : "等待对方")
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
