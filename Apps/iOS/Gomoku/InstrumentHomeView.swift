import SwiftUI
import UniformTypeIdentifiers

struct InstrumentHomeView: View {
    @StateObject private var engine = NativeGomokuAppController()
    @State private var choosingMatch = false
    @State private var matchExportURL: URL?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var appearance = VeilAppearanceController.shared
    @State private var showsEclipseTrace = false

    private var showingSearch: Bool { scenePhase == .active && engine.isThinking }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: VeilSpacing.xxs) {
                    Text("GOMOKU").font(.system(size: 31, weight: .bold, design: .rounded))
                    Text(statusText).font(.caption.monospaced())
                        .foregroundColor(VeilTheme.secondaryText)
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
                HStack(spacing: 12) {
                    Button("NEW GAME") { engine.reset() }
                        .buttonStyle(VeilPhysicalButtonStyle())
                    Button(engine.humanIsBlack ? "BLACK · FIRST" : "WHITE · SECOND") { engine.toggleSide() }
                        .buttonStyle(VeilPhysicalButtonStyle())
                }
                VStack(alignment: .leading, spacing: 8) {
                    Picker("ECLIPSE 难度", selection: $engine.difficulty) {
                        ForEach(BoardBotDifficulty.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("gomoku.eclipse.seven-tiers")

                    Picker("搜索模式", selection: $engine.searchMode) {
                        ForEach(BoardSearchMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("gomoku.eclipse.search-mode")
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach([10, 100, 1000], id: \.self) { count in
                            Button("\(count) 局训练") {
                                engine.beginNativeSelfPlay(games: count)
                            }
                            .disabled(engine.isNativeTraining)
                            .buttonStyle(VeilPhysicalButtonStyle())
                        }
                        if engine.isNativeTraining {
                            Button("停止") { engine.stopNativeSelfPlay() }
                                .buttonStyle(VeilPhysicalButtonStyle())
                        }
                    }
                    Text("已验证唯一训练：\(engine.trainedGames) 局 · 本批完成 \(engine.trainingAttempted)/\(engine.trainingTarget) · 拒收 \(engine.trainingRejected)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Toggle("允许自对弈经验参与正式搜索", isOn: $engine.selfPlayLearningEnabled)
                        .font(.caption)
                }
                HStack(spacing: 12) {
                    Button("导入棋谱 JSON") { choosingMatch = true }
                        .buttonStyle(VeilPhysicalButtonStyle())
                    Button("准备导出最新棋谱") {
                        matchExportURL = engine.exportRecentMatch()
                    }
                    .buttonStyle(VeilPhysicalButtonStyle())
                }
                if let exportURL = matchExportURL {
                    ShareLink(item: exportURL) {
                        Label("分享最新棋谱", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("gomoku.match.share")
                }
                if let warning = engine.fallbackWarning ?? engine.trainingWarning ?? engine.archiveWarning {
                    Text(warning).font(.caption2).foregroundStyle(.orange)
                }
                Toggle(isOn: $engine.eclipseVisualizationEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("棋盘思考可视化").font(.caption.weight(.semibold))
                        Text("显示原生 AI 实际搜索的分支，可能透露棋路。")
                            .font(.caption2)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                }
                .tint(VeilTheme.gold)
                .accessibilityIdentifier("gomoku.eclipse.live-trace.toggle")
                Picker("颜色模式", selection: $appearance.colorMode) {
                    ForEach(VeilColorMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
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
        .fileImporter(isPresented: $choosingMatch,
                      allowedContentTypes: [UTType.json]) { result in
            switch result {
            case .success(let url):
                engine.importMatch(from: url)
            case .failure:
                // Cancellation must not modify any existing chess record.
                break
            }
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
