import Foundation
import SwiftUI

/// Optional, still and deliberately quiet: just the latest ACTUALLY explored
/// native root/reply/continuation. No multi-color trails, sweep, particles,
/// fake trajectories or high-frequency frame rendering. Disabled by default
/// for new installations, with a clear user toggle for explicit inspection.
struct VeilEclipseBoardThoughtField: View {
    let isThinking: Bool
    let actualSearchStartedAt: Date?
    let enabled: Bool
    let searchTrace: VeilEclipseSearchTraceStore
    let sessionID: String
    let turn: Int
    let matchPlaying: Bool

    var body: some View {
        Group {
            if enabled && isThinking && actualSearchStartedAt != nil && matchPlaying {
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    let latest = searchTrace.snapshot(
                        sessionID: sessionID, turn: turn,
                        playing: matchPlaying, aiThinking: isThinking
                    ).last
                    Canvas(opaque: false, rendersAsynchronously: false) { context, area in
                        guard let latest else { return }
                        let side = min(area.width, area.height)
                        let margin = side * 0.055
                        let step = (side - 2 * margin) / 14
                        let points = latest.indices.map { index in
                            CGPoint(x: margin + CGFloat(index % 15) * step,
                                    y: margin + CGFloat(index / 15) * step)
                        }
                        guard !points.isEmpty else { return }
                        var route = Path()
                        route.move(to: points[0])
                        for point in points.dropFirst() { route.addLine(to: point) }
                        context.stroke(
                            route,
                            with: .color(VeilTheme.gold.opacity(0.50)),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                        for (index, point) in points.enumerated() {
                            let size = max(3, step * 0.30)
                            let marker = Path(ellipseIn: CGRect(
                                x: point.x - size, y: point.y - size,
                                width: 2 * size, height: 2 * size
                            ))
                            context.stroke(
                                marker,
                                with: .color(VeilTheme.gold.opacity(index == 0 ? 0.68 : 0.40)),
                                lineWidth: 1
                            )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("game.eclipse.live-examined-branches")
    }
}
