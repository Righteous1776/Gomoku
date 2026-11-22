import SwiftUI
import Foundation

/// Read-only timer tick for the ORIGINAL VeilLink/UI/VeilEclipseBoardThoughtField.
/// This view never draws or invents a search line. It only copies real,
/// atomically published native root/reply search paths to the same validated
/// VeilLink trace store that the pre-existing Canvas already consumes.
struct EclipseNativeVeilLinkTracePump: View {
    let onTick: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(
            minimumInterval: ProcessInfo.processInfo.isLowPowerModeEnabled
                || reduceMotion ? 0.2 : 0.06,
            paused: scenePhase != .active
        )) { timeline in
            Color.clear
                .task(id: timeline.date) {
                    onTick()
                }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
