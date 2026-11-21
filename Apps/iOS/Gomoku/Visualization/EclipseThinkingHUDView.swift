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
            if expanded && engine.developerTeachingMode
                && engine.developerAuthorization.isAuthorized
                && engine.status == 0 {
                Button {
                    engine.analyzeTeachingPosition()
                } label: {
                    Label(
                        engine.isThinking ? "正在分析此局面" : "分析当前局面 · 不自动落子",
                        systemImage: "cpu"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilTheme.goldBright)
                }
                .buttonStyle(.plain)
                .disabled(engine.isThinking)
                .accessibilityIdentifier("gomoku.thinking-hud.teaching-analyze")
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
                            if !snapshot.visibleTeachingPVPrefix.isEmpty {
                                let rootIsBlack = engine.toMove == 1
                                let sequence = snapshot.visibleTeachingPVPrefix
                                    .enumerated().map { ply, index in
                                        "\( (ply % 2 == 0 ? rootIsBlack : !rootIsBlack) ? "黑" : "白") " +
                                        "(\(index % 15 + 1),\(index / 15 + 1))"
                                    }.joined(separator: " → ")
                                item("搜索主变化前缀 · D\(snapshot.nativePVDepth ?? 0)",
                                     sequence)
                                Text("仅含真实完整迭代及精确置换表应手；不足深度已截断，非强制必胜证明。")
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
                            Text(snapshot.context == .formal
                                 ? "正式对局：落子前禁止显示 AI 候选、PV 与必防点。"
                                 : snapshot.context == .teaching
                                   ? "授权教学：仅展示真实原生证据；尚无对应数据时不会生成模拟内容。"
                                   : "赛后复盘：没有可验证 PV 时不显示假设路线。")
                                .font(.caption2)
                                .foregroundColor(VeilTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(snapshot.context == .formal
                                 ? "候选评分、热力图、PV、威胁证明：正式对局不披露未落子信息。"
                                 : snapshot.visibleTeachingRanks.isEmpty
                                   && snapshot.visibleTeachingPVPrefix.isEmpty
                                   ? "候选评分、热力图、PV、威胁证明：本步未获得可核验的原生数据。"
                                   : "候选评分、热力图、PV：原生候选排序和合法前缀可用；原始评分、校准胜率及威胁证明未提供。")
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
