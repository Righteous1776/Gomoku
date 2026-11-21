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
                            if !snapshot.visibleTeachingRanks.isEmpty {
                                let leading = snapshot.visibleTeachingRanks.prefix(5)
                                    .enumerated().map { rank, index in
                                        "#\(rank + 1) (\(index % 15 + 1),\(index / 15 + 1))"
                                    }.joined(separator: " · ")
                                item("C++ 已筛选候选排序 · 共\(snapshot.visibleTeachingRanks.count)",
                                     leading)
                                Text("原生根节点排序热力图：仅代表候选优先级，不是胜率。")
                                    .font(.caption2)
                                    .foregroundColor(VeilTheme.secondaryText)
                            }
                            if let index = snapshot.visibleTeachingCandidate {
                                item("已完成深度最佳落点 · 教学",
                                     "第 \(index / 15 + 1) 行 · 第 \(index % 15 + 1) 列")
                                Text("来自真实 C++ 完整迭代；只是当前搜索候选，非必胜证明。")
                                    .font(.caption2)
                                    .foregroundColor(VeilTheme.secondaryText)
                            }
                            if !snapshot.visibleTeachingPV.isEmpty {
                                let line = snapshot.visibleTeachingPV
                                let notation = line.enumerated().map { offset, index in
                                    "\(offset + 1).(\(index % 15 + 1),\(index / 15 + 1))"
                                }.joined(separator: " → ")
                                item("已完成深度 D\(snapshot.completedDepth ?? 0) · 真实 PV 前缀",
                                     notation)
                                HStack(spacing: 12) {
                                    Button("上一步") { engine.stepTeachingPV(-1) }
                                        .disabled(engine.teachingPVPreviewCount == 0)
                                    Text("预览 \(min(line.count, engine.teachingPVPreviewCount))/\(line.count)")
                                        .font(.caption2.monospacedDigit())
                                    Button("下一步") { engine.stepTeachingPV(1) }
                                        .disabled(engine.teachingPVPreviewCount >= line.count)
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(VeilTheme.goldBright)
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("gomoku.thinking-hud.pv-replay")
                                Text("来自已完成搜索及置换表的合法变化前缀；不足时截断，不是必胜证明。")
                                    .font(.caption2)
                                    .foregroundColor(VeilTheme.secondaryText)
                            }
                            Text(snapshot.context == .formal
                                 ? "正式对局：落子前禁止显示 AI 候选、PV 与必防点。"
                                 : snapshot.context == .teaching
                                   ? "授权教学：只显示同一搜索已完成深度的真实候选与合法变化；不存在时隐藏。"
                                   : "赛后复盘：未提供可信历史 PV 时不展示虚构路线。")
                                .font(.caption2)
                                .foregroundColor(VeilTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("已提供排序热图/有限 PV；尚无校准评分、VCF/VCT 证明或完整深度路线。")
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
                            if let sample = engine.currentNativeLatencySummary() {
                                item("同模型/策略本机样本数", String(sample.count))
                                HStack(spacing: 7) {
                                    item("真实搜索耗时 P50",
                                         "\(sample.p50Milliseconds) ms")
                                    item("真实搜索耗时 P95",
                                         "\(sample.p95Milliseconds) ms")
                                }
                            } else {
                                item("C++ 本机延迟分位",
                                     "相同已验证模型/策略样本不足 20 手")
                            }
                            HStack(spacing: 7) {
                                item("系统热状态（非摄氏温度）", thermalStatus)
                                item("低电量模式",
                                     ProcessInfo.processInfo.isLowPowerModeEnabled ? "开启" : "关闭")
                            }
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

    /// Apple thermal pressure category, not a temperature sensor or joules.
    private var thermalStatus: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "正常"
        case .fair: return "轻度压力"
        case .serious: return "严重压力"
        case .critical: return "临界压力"
        @unknown default: return "系统未提供"
        }
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
