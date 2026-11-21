import Foundation
import SwiftUI

/// Quiet actual-measurement panel, not a rotating timer dial. The live clock
/// is elapsed wall time and MUST NOT be presented as search completion.
struct VeilEclipseRuntimeInstruments: View {
    let running: Bool
    let start: Date?
    let lastNodes: Int?
    let lastMilliseconds: Int?
    let trainedGames: Int
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("ECLIPSE / 实测仪表", systemImage: "cpu")
                    .font(.system(size: 12, weight: .semibold,
                                  design: .monospaced))
                Spacer()
                Text(running && start != nil ? "RUN" : "IDLE")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(VeilTheme.secondaryText)
            }
            TimelineView(.periodic(from: .now, by: scenePhase == .active ? 1 : 10)) { time in
                let seconds = running && start != nil
                    ? max(0, time.date.timeIntervalSince(start!)) : nil
                HStack(spacing: 8) {
                    cell("实际耗时", seconds.map { String(format: "%.1fs", $0) } ?? "—")
                    cell("上次节点", lastNodes.map(String.init) ?? "—")
                    cell("已验证局数", String(max(0, trainedGames)))
                }
            }
            Text("耗时只是实际运行时间，不代表搜索完成比例。")
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("game.eclipse.measured-instruments")
    }

    private func cell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(VeilTheme.secondaryText)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(VeilTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(VeilTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8))
    }
}
