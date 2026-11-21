import Foundation
import SwiftUI

/// ECLIPSE measured analysis console. No synthetic code stream, animated
/// numbers, simulated progress, search paths or decorative redraw loops.
/// All figures originate from actual engine measurements.
struct VeilEclipseComputeConsole: View {
    let isComputing: Bool
    let actualSearchStartedAt: Date?
    let liveMetrics: VeilEclipseTracePolicy.LiveMetrics?
    var compact: Bool = false

    private var active: Bool {
        isComputing && actualSearchStartedAt != nil
    }

    private var elapsedSeconds: Double? {
        guard active, let actualSearchStartedAt else { return nil }
        return max(0, Date().timeIntervalSince(actualSearchStartedAt))
    }

    private var nodesPerSecond: String {
        guard let nodes = liveMetrics?.visitedNodes,
              let elapsedSeconds, elapsedSeconds >= 0.5 else { return "—" }
        return "\(Int(Double(nodes) / elapsedSeconds))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(active ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                    .frame(width: 5, height: 5)
                Text("ECLIPSE / 实测搜索")
                    .font(.system(size: compact ? 10 : 12,
                                  weight: .semibold, design: .monospaced))
                    .foregroundColor(VeilTheme.text)
                Spacer(minLength: 4)
                Text(active ? "计算中" : "待机")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
            }

            HStack(spacing: compact ? 6 : 12) {
                metric("完成深度",
                       liveMetrics?.completedDepth.map { "D\($0)" } ?? "—")
                metric("搜索节点",
                       liveMetrics?.visitedNodes.map(String.init) ?? "—")
                if !compact {
                    metric("实际节点/秒", nodesPerSecond)
                }
            }

            if !compact {
                Text("仅显示引擎测量数据；没有虚构的搜索日志或进度百分比。")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
            }
        }
        .padding(compact ? 10 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            VeilTheme.elevated,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(VeilTheme.subtleStroke, lineWidth: 0.7)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ECLIPSE 实测搜索。\(active ? "计算中" : "待机")。完成深度 \(liveMetrics?.completedDepth.map(String.init) ?? "未知")，累计节点 \(liveMetrics?.visitedNodes.map(String.init) ?? "未知")。")
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(VeilTheme.secondaryText)
            Text(value)
                .font(.system(size: compact ? 12 : 16,
                              weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(VeilTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
