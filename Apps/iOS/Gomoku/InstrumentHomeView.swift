import SwiftUI
import UniformTypeIdentifiers

struct InstrumentHomeView: View {
    @StateObject private var engine = NativeGomokuAppController()
    @State private var showsAdvancedPanel = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var appearance = VeilAppearanceController.shared
    @State private var showsEclipseTrace = false

    private var showingSearch: Bool { scenePhase == .active && engine.isThinking }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: VeilSpacing.sm) {
                    VStack(alignment: .leading, spacing: VeilSpacing.xxs) {
                        Text("GOMOKU").font(.system(size: 31, weight: .bold, design: .rounded))
                        Text(statusText).font(.caption.monospaced())
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                    Button { showsAdvancedPanel = true } label: {
                        Label("高级面板", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(VeilPhysicalButtonStyle())
                    .accessibilityIdentifier("gomoku.advanced.open")
                }
                VeilEclipseIdentityCard(
                    isThinking: showingSearch,
                    matchFinished: engine.status != 0,
                    lastCompletedMilliseconds: engine.lastDecisionMilliseconds,
                    actualSearchStartedAt: showingSearch ? engine.searchStartedAt : nil,
                    difficultyTitle: engine.difficulty.title,
                    liveMetrics: nil,
                    openTrace: { showsEclipseTrace = true }
                )
                .veilCard()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("gomoku.eclipse.upper-compute-console")

                GomokuBoardView(
                    state: engine.state,
                    localPlayer: engine.humanIsBlack ? .host : .guest,
                    enabled: engine.status == 0 && !engine.isThinking && engine.toMove == engine.humanColor,
                    eclipseThinking: showingSearch,
                    actualSearchStartedAt: engine.searchStartedAt,
                    eclipseVisualizationEnabled: engine.eclipseVisualizationEnabled,
                    eclipseTraceStore: engine.eclipseTraceStore,
                    eclipseSessionID: engine.sessionID,
                    eclipseBoardTurn: engine.state.moveCount,
                    eclipseMatchPlaying: engine.status == 0,
                    onMove: { engine.play($0) }
                )
                .veilCard()
                VStack(alignment: .leading, spacing: VeilSpacing.sm) {
                    Picker("ECLIPSE 难度", selection: $engine.difficulty) {
                        ForEach(BoardBotDifficulty.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(VeilTheme.gold)
                    .accessibilityIdentifier("gomoku.eclipse.seven-tiers")

                    Picker("搜索模式", selection: $engine.searchMode) {
                        ForEach(BoardSearchMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("gomoku.eclipse.search-mode")

                    HStack(spacing: VeilSpacing.xs) {
                        Button { engine.reset() } label: {
                            MatchKey(title: "重开", icon: "arrow.counterclockwise")
                        }
                        Button { engine.toggleSide() } label: {
                            MatchKey(title: engine.humanIsBlack ? "执黑 · 先手" : "执白 · 后手",
                                     icon: "circle.lefthalf.filled")
                        }
                    }
                    .buttonStyle(VeilPhysicalButtonStyle())
                }
                .veilCard()
            }
            .padding(18)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .foregroundColor(VeilTheme.text)
        .background(VeilInstrumentBackground())
        .preferredColorScheme(appearance.preferredColorScheme)
        .onAppear { appearance.update(colorScheme: scheme) }
        .onChange(of: scheme) { appearance.update(colorScheme: $0) }
        .sheet(isPresented: $showsEclipseTrace) {
            EclipseAnalysisPresentation(engine: engine)
        }
        .sheet(isPresented: $showsAdvancedPanel) {
            GomokuAdvancedPanel(engine: engine)
        }
    }

    private var statusText: String {
        switch engine.status {
        case 1: return "BLACK WINS"
        case 2: return "WHITE WINS"
        case 3: return "DRAW"
        default: return engine.isThinking ? "AI THINKING" : engine.toMove == 1 ? "BLACK TO MOVE" : "WHITE TO MOVE"
        }
    }
}

private struct EclipseAnalysisPresentation: View {
    @ObservedObject var engine: NativeGomokuAppController
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let active = scenePhase == .active && engine.isThinking
        VeilEclipseTraceSheet(
            isThinking: active,
            matchFinished: engine.status != 0,
            lastCompletedMilliseconds: engine.lastDecisionMilliseconds,
            actualSearchStartedAt: active ? engine.searchStartedAt : nil,
            committedMoves: engine.completedMoves,
            difficultyTitle: engine.difficulty.title,
            searchModeTitle: engine.searchMode.title,
            liveMetrics: nil,
            archivedMatchPage: engine.historyPage(offset:limit:)
        )
    }
}

private struct MatchKey: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 24)
    }
}

private struct GomokuAdvancedPanel: View {
    @ObservedObject var engine: NativeGomokuAppController
    @ObservedObject private var appearance = VeilAppearanceController.shared
    @Environment(\.dismiss) private var dismiss
    @State private var choosingMatch = false
    @State private var matchExportURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VeilSpacing.md) {
                    VStack(alignment: .leading, spacing: VeilSpacing.sm) {
                        sectionTitle("搜索与显示", icon: "waveform.path")
                        Toggle(isOn: $engine.eclipseVisualizationEnabled) {
                            VStack(alignment: .leading, spacing: VeilSpacing.xxs) {
                                Text("棋盘思考可视化")
                                Text("显示 AI 实际搜索过的棋路。下一次 AI 回合生效。")
                                    .font(.caption)
                                    .foregroundColor(VeilTheme.secondaryText)
                            }
                        }
                        .tint(VeilTheme.gold)
                        .accessibilityIdentifier("gomoku.eclipse.live-trace.toggle")

                        Picker("颜色模式", selection: $appearance.colorMode) {
                            Text("跟随系统").tag(VeilColorMode.automatic)
                            Text("浅色").tag(VeilColorMode.light)
                            Text("深夜").tag(VeilColorMode.dark)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("gomoku.appearance.mode")
                    }
                    .veilCard()

                    VStack(alignment: .leading, spacing: VeilSpacing.sm) {
                        sectionTitle("自对弈训练", icon: "cpu")
                        Text("已保存 \(engine.trainedGames) 局")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(VeilTheme.secondaryText)
                        Button { engine.beginNativeSelfPlay(games: 1) } label: {
                            MatchKey(title: engine.isNativeTraining ? "训练进行中" : "开始一局自对弈", icon: "play.fill")
                        }
                        .buttonStyle(VeilPhysicalButtonStyle())
                        .disabled(engine.isNativeTraining)
                        if let warning = engine.trainingWarning {
                            Text(warning).font(.caption).foregroundColor(VeilTheme.danger)
                        }
                    }
                    .veilCard()

                    VStack(alignment: .leading, spacing: VeilSpacing.sm) {
                        sectionTitle("棋谱", icon: "books.vertical")
                        Text("已保存 \(engine.archivedGames) 份")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(VeilTheme.secondaryText)
                        Button { choosingMatch = true } label: {
                            MatchKey(title: "导入棋谱", icon: "square.and.arrow.down")
                        }
                        .buttonStyle(VeilPhysicalButtonStyle())
                        if let exportURL = matchExportURL {
                            ShareLink(item: exportURL) {
                                MatchKey(title: "分享最新棋谱", icon: "square.and.arrow.up")
                            }
                            .buttonStyle(VeilPhysicalButtonStyle())
                            .accessibilityIdentifier("gomoku.match.share")
                        } else {
                            Button { matchExportURL = engine.exportRecentMatch() } label: {
                                MatchKey(title: "导出最新棋谱", icon: "square.and.arrow.up")
                            }
                            .buttonStyle(VeilPhysicalButtonStyle())
                            .disabled(engine.archivedGames == 0)
                        }
                        if let warning = engine.archiveWarning {
                            Text(warning).font(.caption).foregroundColor(VeilTheme.danger)
                        }
                    }
                    .veilCard()
                }
                .padding(VeilSpacing.md)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .foregroundColor(VeilTheme.text)
            .background(VeilInstrumentBackground())
            .navigationTitle("高级面板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.tint(VeilTheme.gold)
                }
            }
            .fileImporter(isPresented: $choosingMatch, allowedContentTypes: [UTType.json]) { result in
                if case .success(let url) = result {
                    engine.importMatch(from: url)
                    matchExportURL = nil
                }
            }
        }
        .preferredColorScheme(appearance.preferredColorScheme)
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(VeilTheme.text)
            .accessibilityAddTraits(.isHeader)
    }
}
