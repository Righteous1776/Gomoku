import SwiftUI
import Foundation

/// Stage A / Issue #50. A read-only footer INSIDE the original VeilLink
/// runtime instrument card. No duplicate gauge, no new board overlay.
/// Real C++ V2 gives complete depth/nodes only AFTER the call returns;
/// missing fields remain nil. The old decorative VISUAL STREAM is not
/// used as a source of telemetry.
struct EclipseThinkingHUDView: View {
    @ObservedObject var engine: NativeGomokuAppController
    @AppStorage("gomoku.eclipse.hud.detail.v1") private var detailRaw = "compact"
    @State private var expanded = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Detail: String, CaseIterable {
        case compact, professional, developer
        var title: String {
            switch self {
            case .compact: return "简洁"
            case .professional: return "专业"
            case .developer: return "开发者"
            }
        }
    }

    private var level: Detail { Detail(rawValue: detailRaw) ?? .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Button {
                    expanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption2.weight(.semibold))
                        Text("THINKING HUD")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(VeilTheme.goldBright)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("gomoku.thinking-hud.expand")
                .accessibilityValue(expanded ? "已展开" : "已折叠")
                Spacer(minLength: 4)
                if expanded {
                    Menu {
                        ForEach(Detail.allCases, id: \.self) { choice in
                            Button {
                                detailRaw = choice.rawValue
                            } label: {
                                if choice == level {
                                    Label(choice.title, systemImage: "checkmark")
                                } else {
                                    Text(choice.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(level.title)
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(VeilTheme.secondaryText)
                    }
                    .accessibilityIdentifier("gomoku.thinking-hud.level")
                }
            }
            if expanded {
                // Only this footer refreshes. 2 Hz in foreground, 1 Hz for
                // Reduce Motion / Low Power; no background stream or board
                // overlays. No percent/progress bar exists for adaptive search.
                TimelineView(.periodic(
                    from: .now,
                    by: scenePhase != .active ? 30 :
                        (reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 : 0.5)
                )) { _ in
                    let snapshot = engine.thinkingHUDSnapshot()
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            item("状态", snapshot.shortStatus)
                            item("实际后端", snapshot.backend)
                        }
                        HStack(spacing: 7) {
                            item("运行模型", snapshot.executedModel ?? "未提供")
                            item("完成深度", snapshot.completedDepth.map { "D\($0)" } ?? "未提供")
                        }
                        if level != .compact {
                            HStack(spacing: 7) {
                                item("搜索节点", snapshot.visitedNodes.map(String.init) ?? "未提供")
                                item("平均 NPS", snapshot.averageNPS.map(String.init) ?? "未提供")
                            }
                            item("终止原因", snapshot.stopReason ?? "未提供")
                            Text(snapshot.context == .formal
                                 ? "正式对局：落子前禁止显示 AI 候选、PV 与必防点。"
                                 : snapshot.context == .teaching
                                   ? "授权教学：候选/PV 接口尚未提供，不生成演示数据。"
                                   : "赛后复盘：没有可验证 PV 时不显示假设路线。")
                                .font(.caption2)
                                .foregroundColor(VeilTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("候选评分、热力图、PV、威胁证明：当前接口未提供")
                                .font(.caption2)
                                .foregroundColor(VeilTheme.tertiaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !snapshot.isSearching && snapshot.elapsedMilliseconds != nil {
                            Text(snapshot.backend == "未提供"
                                 ? "无法可靠解释本手：没有引擎决策证据。"
                                 : "本手已执行；引擎未提供可验证的战术解释。")
                                .font(.caption2)
                                .foregroundColor(VeilTheme.secondaryText)
                        }
                        if level == .developer {
                            item("位置版本", String(snapshot.positionRevision))
                            item("搜索 ID", snapshot.searchID?.uuidString ?? "未提供")
                            item("模型 SHA-256", snapshot.checkpointSHA256 ?? "未提供")
                            item("策略 SHA-256", snapshot.computePolicySHA256 ?? "未提供")
                            Text("仅限已核验的实际运行身份；不显示私人棋谱。")
                                .font(.caption2)
                                .foregroundColor(VeilTheme.tertiaryText)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("gomoku.thinking-hud.metrics")
                }
            }
        }
        .padding(.top, 9)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(VeilTheme.hairline)
                .frame(height: 0.5)
                .allowsHitTesting(false)
        }
        .accessibilityIdentifier("gomoku.thinking-hud")
    }

    private func item(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(VeilTheme.tertiaryText)
            Text(value)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundColor(VeilTheme.text)
                .lineLimit(label.contains("SHA") ? 3 : 2)
                .minimumScaleFactor(0.72)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
