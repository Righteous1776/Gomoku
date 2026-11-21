import SwiftUI
import UniformTypeIdentifiers

/// Standalone adaptation of VeilLink/UI/GameLobbyView.swift's LocalAIGameView.
/// Keep the original instrument hierarchy: status, ECLIPSE identity, quick controls,
/// board and a collapsed learning laboratory. Do not put training controls ahead
/// of the board or borrow the unrelated messenger/game-hall tab bar.
struct InstrumentHomeView: View {
    @StateObject private var engine = NativeGomokuAppController()
    @State private var choosingMatch = false
    @State private var showingDeveloperLab = false
    @State private var showingCoach = false
    @State private var showsAdvanced = false
    @State private var showsInstruments = false
    @State private var showsEclipseTrace = false
    @State private var showsModelSelection = false
    @State private var pendingModel: EclipseModelID?
    @State private var pendingCompute: EclipseComputeTier?
    @State private var matchExportURL: URL?

    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var appearance = VeilAppearanceController.shared

    private var showingSearch: Bool { scenePhase == .active && engine.isThinking }
    private var canPlaceStone: Bool {
        engine.status == 0 && !engine.isThinking &&
        (engine.developerTeachingMode || engine.toMove == engine.humanColor)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {
                    if viewport.size.width >= 900 {
                        // Regular-width iPad landscape: a playable tabletop
                        // beside a separate cockpit, not a stretched iPhone.
                        HStack(alignment: .top, spacing: 18) {
                            VStack(alignment: .leading, spacing: 12) {
                                eclipseIdentity
                                boardQuickControls
                                board
                                liveSearchRibbon
                            }
                            .frame(maxWidth: 680)
                            VStack(alignment: .leading, spacing: 12) {
                                statusCard
                                if engine.status != 0 { resultCard }
                                advancedPanel
                            }
                            .frame(maxWidth: 340)
                        }
                        .frame(maxWidth: 1_100)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            // Portrait iPhone and iPad split view: the native
                            // board stays full-width and above deep settings.
                            eclipseIdentity
                            boardQuickControls
                            board
                            liveSearchRibbon
                            if engine.status != 0 { resultCard }
                            statusCard
                            advancedPanel
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 28)
                        .frame(maxWidth: 680)
                        .frame(maxWidth: .infinity)
                    }
                }
                .scrollIndicators(.hidden)
                .background(VeilInstrumentBackground())
            }
            .navigationTitle("GOMOKU")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsModelSelection = true
                    } label: {
                        Label("模型", systemImage: "cpu")
                    }
                    .accessibilityIdentifier("gomoku.eclipse.model.open")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("重开") { engine.reset() }
                        .foregroundColor(VeilTheme.goldBright)
                        .accessibilityIdentifier("gomoku.match.restart")
                }
            }
        }
        .foregroundColor(VeilTheme.text)
        .tint(VeilTheme.gold)
        .preferredColorScheme(appearance.preferredColorScheme)
        .onAppear { appearance.update(colorScheme: scheme) }
        .onChange(of: scheme) { appearance.update(colorScheme: $0) }
        .sheet(isPresented: $showsEclipseTrace) {
            EclipseAnalysisPresentation(engine: engine)
        }
        .sheet(isPresented: $showsModelSelection) {
            modelSelectionSheet
        }
        .confirmationDialog(
            "更改算力将结束当前对局并重开",
            isPresented: Binding(
                get: { pendingCompute != nil },
                set: { if !$0 { pendingCompute = nil } }
            )
        ) {
            if let tier = pendingCompute {
                Button("切换至 \(tier.title)算力并重开") {
                    engine.selectComputeTier(tier)
                    pendingCompute = nil
                }
            }
            Button("取消", role: .cancel) { pendingCompute = nil }
        } message: {
            Text("选择后将重新启动一局棋，旧棋局数据仍保持原来的模型和算力归属。")
        }
        .sheet(isPresented: $showingCoach) {
            GomokuCoachView(engine: engine)
        }
        .sheet(isPresented: $showingDeveloperLab) {
            GomokuDeveloperLearningLabView(
                engine: engine, authorization: engine.developerAuthorization
            )
        }
        .fileImporter(isPresented: $choosingMatch, allowedContentTypes: [.json]) { result in
            if case let .success(url) = result {
                engine.importMatch(from: url)
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Picker("你的棋子", selection: Binding(
                get: { engine.humanIsBlack },
                set: { if $0 != engine.humanIsBlack { engine.toggleSide() } }
            )) {
                Text("黑 · 先手").tag(true)
                Text("白 · 后手").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("gomoku.match.side")

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(canPlaceStone ? VeilTheme.goldBright : VeilTheme.text)
                    Text("你 vs ECLIPSE \(engine.selectedModel.name) · 离线对局")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer(minLength: 4)
                if showingSearch {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("ECLIPSE 正在计算")
                } else {
                    VeilIndicatorLamp(active: canPlaceStone, color: VeilTheme.goldBright)
                }
            }
            HStack(spacing: 7) {
                statusMetric("实际引擎", engine.lastExecutionBackend
                    ?? (engine.trainerControlsCompute
                        ? "C++ V2 / 待核验" : "Swift / 历史兼容"))
                statusMetric("联网", "不需要")
                statusMetric("上步耗时", engine.lastDecisionMilliseconds.map { "\($0)ms" } ?? "—")
            }
            if let executed = engine.lastExecutedModel {
                Text("上一手：\(executed.name) · \(engine.lastExecutionBackend ?? "Swift")")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(VeilTheme.secondaryText)
                    .accessibilityIdentifier("gomoku.eclipse.last-executed-model")
            }
            if engine.recoveryAvailable {
                Button {
                    _ = engine.restoreLastPlayingSession()
                } label: {
                    Label("恢复上次未完成棋局", systemImage: "arrow.counterclockwise.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(VeilTheme.goldBright)
                .accessibilityIdentifier("gomoku.match.resume")
            }
            if let warning = engine.fallbackWarning ?? engine.trainingWarning ?? engine.archiveWarning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .veilCard(emphasized: true)
        .accessibilityIdentifier("gomoku.instrument.status")
    }

    private func statusMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(VeilTheme.secondaryText)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(VeilTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(VeilTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8))
    }

    private var eclipseIdentity: some View {
        // Only the instrument header is periodically redrawn; the board and
        // its tap surface are not rebuilt at the telemetry refresh cadence.
        TimelineView(.periodic(from: .now,
                               by: showingSearch && !reduceMotion ? 0.5 : 5)) { _ in
            VeilEclipseIdentityCard(
                isThinking: showingSearch,
                matchFinished: engine.status != 0,
                lastCompletedMilliseconds: engine.lastDecisionMilliseconds,
                actualSearchStartedAt: showingSearch ? engine.searchStartedAt : nil,
                difficultyTitle: engine.selectedModel.name,
                liveMetrics: engine.realSearchMetrics,
                openTrace: { showsEclipseTrace = true },
                matchupLabel: "你 vs ECLIPSE \(engine.selectedModel.name) · 离线对局"
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("gomoku.eclipse.upper-compute-console")
        }
    }

    /// In regular widths the same compact VeilLink row is retained; larger
    /// content sizes and narrow split-screen layouts fall back to two rows
    /// instead of clipping the 6× tier or intercepting the board below.
    private var boardQuickControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                modelSelector
                Spacer(minLength: 3)
                computeSelector
                deepSearchToggle
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    modelSelector
                    Spacer(minLength: 4)
                    computeSelector
                }
                deepSearchToggle
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background {
            ZStack {
                VeilInstrumentPlate(
                    shape: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                VeilGlassPanel(cornerRadius: 11).padding(4)
            }
        }
        .overlay(VeilMachinedRim(cornerRadius: 14, width: 1.35))
        .accessibilityIdentifier("gomoku.instrument.quick-controls")
    }

    /// Model identity is not the same thing as a generic difficulty slider.
    /// The chosen model is a real runtime dispatch policy with a stable ID,
    /// persisted across launches and (without modifying legacy records) games.
    private var modelSelector: some View {
        Button {
            showsModelSelection = true
        } label: {
            Label(engine.selectedModel.name, systemImage: "cpu")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(VeilTheme.goldBright)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityIdentifier("gomoku.eclipse.model.selector")
        .accessibilityLabel("选择模型，当前 \(engine.selectedModel.name)")
    }

    private var modelSelectionSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "cpu.fill")
                            .foregroundColor(VeilTheme.goldBright)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ECLIPSE / MODEL LIBRARY")
                                .font(.caption.monospaced().weight(.bold))
                                .foregroundColor(VeilTheme.goldBright)
                            Text("选择实际执行的搜索模型")
                                .font(.headline)
                                .foregroundColor(VeilTheme.text)
                        }
                    }
                    .padding(.bottom, 6)

                    ForEach(engine.availableModels) { model in
                        Button {
                            requestModelSelection(model)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(model.name)
                                        .font(.headline)
                                        .foregroundColor(VeilTheme.text)
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundColor(VeilTheme.secondaryText)
                                        .multilineTextAlignment(.leading)
                                    if model == .astra10 {
                                        Text("经典 Swift 搜索 · 可作为旧版棋力对照")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundColor(VeilTheme.goldBright)
                                    } else if model.requiresVerifiedCheckpoint {
                                        Text("2.0 C++ 搜索 · 实战棋力回归验证中")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundColor(VeilTheme.secondaryText)
                                    }
                                    Text(model.backendDescription)
                                        .font(.caption2.monospaced())
                                        .foregroundColor(VeilTheme.goldBright)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 2)
                                VStack(alignment: .trailing, spacing: 6) {
                                    if model == engine.selectedModel {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(VeilTheme.goldBright)
                                            .accessibilityLabel("当前模型")
                                    }
                                    Text("策略可更新")
                                        .font(.caption2.monospaced())
                                        .foregroundColor(VeilTheme.secondaryText)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                model == engine.selectedModel
                                    ? VeilTheme.subtleFillStrong : VeilTheme.subtleFill,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("gomoku.eclipse.model.\(model.rawValue)")
                    }
                    Text("棋力回归保护已开启：ECLIPSE 2.0 正式对局停用未经实战验证的浅层提前落子；保留必胜、必防的快速判断与完整逐层搜索。Astra 最多 30 秒，Sol 最多 8 秒是搜索上限，并不代表棋力已经超过经典 Swift。你可以选择旧版 Astra 进行对照。")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                        .padding(.top, 6)
                }
                .padding(16)
            }
            .background(VeilInstrumentBackground())
            .navigationTitle("ECLIPSE 模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showsModelSelection = false }
                        .foregroundColor(VeilTheme.goldBright)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "切换模型将结束当前对局并重开",
            isPresented: Binding(
                get: { pendingModel != nil },
                set: { if !$0 { pendingModel = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let model = pendingModel {
                Button("切换至 \(model.name) 并重开") {
                    engine.selectModel(model)
                    pendingModel = nil
                    showsModelSelection = false
                }
            }
            Button("取消", role: .cancel) {
                pendingModel = nil
            }
        } message: {
            Text("这是一次真实的模型策略切换；旧对局保留在历史记录中，不会把两种模型的落子混成一局训练证据。")
        }
    }

    private func requestModelSelection(_ model: EclipseModelID) {
        guard model != engine.selectedModel else {
            showsModelSelection = false
            return
        }
        if engine.state.moveCount > 0 || engine.isThinking {
            pendingModel = model
        } else {
            engine.selectModel(model)
            showsModelSelection = false
        }
    }

    private var computeSelector: some View {
        Menu {
            ForEach(EclipseComputeTier.allCases) { tier in
                Button {
                    guard tier != engine.computeTier else { return }
                    if engine.state.moveCount > 0 || engine.isThinking {
                        pendingCompute = tier
                    } else {
                        engine.selectComputeTier(tier)
                    }
                } label: {
                    if tier == engine.computeTier {
                        Label(tier.title, systemImage: "checkmark")
                    } else {
                        Text(tier.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text("算力")
                Text(engine.trainerControlsCompute ? "训练 Agent" : engine.computeTier.title)
                    .foregroundColor(VeilTheme.goldBright)
                Image(systemName: "chevron.up.chevron.down")
            }
            .font(.caption.weight(.medium))
            .foregroundColor(VeilTheme.text)
        }
        .disabled(engine.trainerControlsCompute)
        .accessibilityHint(engine.trainerControlsCompute
            ? "训练模型参数由训练 Agent 核验；落子时机由局面复杂度和多轮搜索稳定性自主判断"
            : "当前为原版 Swift 历史兼容策略；新的训练检查点不会被旧档位时间限制")
        .accessibilityIdentifier("gomoku.eclipse.compute.selector")
    }

    private var deepSearchToggle: some View {
        Group {
            if engine.trainerControlsCompute {
                Label("棋力保护", systemImage: "shield.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilTheme.goldBright)
                    .accessibilityHint("已暂停未经对局验证的浅层提前落子；保留完整搜索深度及真实战术证明")
            } else {
                Toggle(isOn: Binding(
                    get: { engine.searchMode == .full },
                    set: { engine.searchMode = $0 ? .full : .economy }
                )) {
                    Text("深入分析").font(.caption.weight(.semibold))
                }
                .tint(VeilTheme.gold)
            }
        }
        .frame(minHeight: 44)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityIdentifier("gomoku.eclipse.search-mode")
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "circle.hexagongrid")
                    .foregroundColor(VeilTheme.goldBright)
                Text("01  /  MATCH ARENA")
                    .foregroundColor(VeilTheme.secondaryText)
                    .tracking(1.5)
                Spacer(minLength: 4)
                Text("\(engine.state.moveCount) PLY  ·  15 × 15")
                    .foregroundColor(VeilTheme.goldBright)
                    .monospacedDigit()
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 4)
            GomokuBoardView(
            state: engine.state,
            localPlayer: engine.humanIsBlack ? .host : .guest,
            enabled: canPlaceStone,
            eclipseThinking: showingSearch,
            actualSearchStartedAt: engine.searchStartedAt,
            eclipseVisualizationEnabled: engine.eclipseVisualizationEnabled,
            eclipseTraceStore: engine.eclipseTraceStore,
            eclipseSessionID: engine.sessionID,
            eclipseBoardTurn: engine.state.moveCount,
            eclipseMatchPlaying: engine.status == 0,
            onMove: { engine.play($0) }
            )
        }
        // Keep native board tap geometry at full available width.
        // The wood board already owns its material and 5.5% edge-safe grid
        // inset. Adding a second 16pt-padded instrument plate wasted 32pt of
        // usable width on small phones, shrinking stones and tap targets.
        // Keep the ScrollView's outer 14pt gutter, without a nested frame.
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("gomoku.instrument.board")
    }

    // True search metrics only. No guessed progress percent or move timer.
    // The ribbon updates independently; the board is not rebuilt at 4 FPS.
    private var liveSearchRibbon: some View {
        TimelineView(.periodic(from: .now, by: showingSearch ? 0.25 : 8)) { clock in
            let elapsedText: String = {
                if showingSearch, let started = engine.searchStartedAt {
                    return String(format: "%.1fs",
                                  max(0, clock.date.timeIntervalSince(started)))
                }
                if let ms = engine.lastDecisionMilliseconds {
                    return String(format: "%.2fs", Double(ms) / 1000)
                }
                return "—"
            }()
            let metrics = engine.realSearchMetrics
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 7) {
                    telemetryCell("耗时 / REAL", value: elapsedText)
                    telemetryCell("搜索深度", value: metrics?.completedDepth.map { "D\($0)" } ?? "—")
                    telemetryCell("实际节点", value: metrics?.visitedNodes.map(String.init) ?? "—")
                    telemetryActions
                }
                HStack(spacing: 6) {
                    telemetryCell("真实耗时", value: elapsedText)
                    telemetryCell("深度", value: metrics?.completedDepth.map { "D\($0)" } ?? "—")
                    telemetryActions
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    VeilInstrumentPlate(
                        shape: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    VeilGlassPanel(cornerRadius: 11).padding(4)
                }
                .overlay(VeilMachinedRim(cornerRadius: 14, width: 1.2))
            )
        }
        .accessibilityIdentifier("gomoku.eclipse.live-telemetry")
    }

    private func telemetryCell(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(VeilTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(VeilTheme.goldBright)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .padding(.horizontal, 6)
        .background {
            VeilGlassPanel(cornerRadius: 7)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(VeilTheme.subtleStroke, lineWidth: 0.7)
                .allowsHitTesting(false)
        )
        .accessibilityElement(children: .combine)
    }

    private var telemetryActions: some View {
        HStack(spacing: 2) {
            Button {
                engine.eclipseVisualizationEnabled.toggle()
            } label: {
                Image(systemName: engine.eclipseVisualizationEnabled
                    ? "eye.fill" : "eye.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        VeilTheme.subtleFillStrong,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(engine.eclipseVisualizationEnabled
                ? "关闭棋盘思考可视化" : "开启棋盘思考可视化")
            .accessibilityIdentifier("gomoku.eclipse.live-visibility")
            Button {
                showsEclipseTrace = true
            } label: {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        VeilTheme.subtleFillStrong,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("查看详细分析")
            .accessibilityIdentifier("gomoku.eclipse.analysis.open")
        }
        .buttonStyle(.plain)
        .foregroundColor(VeilTheme.goldBright)
    }

    private var resultCard: some View {
        HStack(spacing: 9) {
            Image(systemName: engine.status == 3 ? "equal.circle" : "flag.checkered")
                .foregroundColor(VeilTheme.goldBright)
            Text(statusText).font(.subheadline.weight(.semibold))
            Spacer()
            Button("再来一局") { engine.reset() }
                .font(.caption.weight(.semibold))
                .foregroundColor(VeilTheme.goldBright)
        }
        .veilCard()
    }

    private var advancedPanel: some View {
        VStack(spacing: 9) {
            Button {
                showsAdvanced.toggle()
                if showsAdvanced { engine.refreshCoachProfile() }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(VeilTheme.gold)
                    Text("训练实验室 · 高级设置")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(VeilTheme.text)
                    Spacer(minLength: 6)
                    Text("已验证 \(engine.trainedGames) 局")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(VeilTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: showsAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(VeilTheme.goldBright)
                }
                .padding(12)
                .background(VeilTheme.elevated.opacity(0.82),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("gomoku.training.advanced.toggle")
            .accessibilityValue(showsAdvanced ? "已展开" : "已收起")

            if showsAdvanced {
                learningCard
                historyCard
                appearanceCard
            }
        }
    }

    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(VeilTheme.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text("本地自学习棋手")
                        .font(.subheadline.weight(.bold))
                    Text(learningSummary)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(VeilTheme.goldBright)
                }
                Spacer(minLength: 0)
                if engine.isCoachLoading || engine.isInitialTrainingAuditRunning {
                    ProgressView().controlSize(.mini)
                }
            }
            Text("仅使用本机校验通过的五子棋记录；导入的棋谱不会自动冒充本机训练经验。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $engine.eclipseVisualizationEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("棋盘思考可视化").font(.caption.weight(.semibold))
                    Text("仅显示真实搜索过的分支；默认开启，可随时关闭。")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
            }
            .tint(VeilTheme.gold)
            .accessibilityIdentifier("gomoku.eclipse.live-trace.toggle")

            HStack(spacing: 8) {
                Image(systemName: "cpu").foregroundColor(VeilTheme.goldBright)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ECLIPSE 原生搜索")
                        .font(.caption.weight(.semibold))
                    Text("统一原生战术安全门、训练排序与深度搜索")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
            }

            Menu {
                ForEach(GomokuFormationMode.allCases) { mode in
                    Button {
                        engine.formationMode = mode
                    } label: {
                        if mode == engine.formationMode {
                            Label(mode.title, systemImage: "checkmark")
                        } else {
                            Text(mode.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                    Text("阵法学习").font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Text(engine.formationMode.title)
                        .font(.caption2)
                    Image(systemName: "chevron.up.chevron.down")
                }
                .foregroundColor(VeilTheme.goldBright)
                .padding(10)
                .background(VeilTheme.subtleFillStrong,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityIdentifier("gomoku.formation.menu")
            Text("阵法偏好通过原生引擎影响排序，不提供未发生落点建议。")
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
            trainingSection
            coachSection

            Button {
                showsInstruments.toggle()
            } label: {
                HStack {
                    Label("ECLIPSE / 实测仪表", systemImage: "cpu.fill")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: showsInstruments ? "chevron.up" : "chevron.down")
                }
                .foregroundColor(VeilTheme.goldBright)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("gomoku.eclipse.instruments.toggle")
            if showsInstruments {
                VeilEclipseRuntimeInstruments(
                    running: showingSearch,
                    start: showingSearch ? engine.searchStartedAt : nil,
                    lastNodes: engine.lastDecisionNodes,
                    lastMilliseconds: engine.lastDecisionMilliseconds,
                    trainedGames: engine.trainedGames
                )
            }

            Button {
                showingDeveloperLab = true
            } label: {
                Label("开发训练室 · 设备身份验证", systemImage: "lock.shield")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(VeilPhysicalButtonStyle())
        }
        .veilCard()
        .accessibilityIdentifier("gomoku.training.learning-card")
    }

    private var learningSummary: String {
        if let profile = engine.coachProfile {
            return "已验证 \(profile.verifiedSelfPlayGames) 局 · \(profile.rememberedPositions) 个局面"
        }
        return engine.isInitialTrainingAuditRunning
            ? "正在核验本机训练库"
            : "已验证 \(engine.trainedGames) 局 · 局面统计待载入"
    }

    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "repeat.circle")
                    .foregroundColor(VeilTheme.gold)
                Text("原生 Bot 自对弈训练")
                    .font(.caption.weight(.bold))
                Spacer(minLength: 0)
                Text("已验证 \(engine.trainedGames) 局")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(VeilTheme.goldBright)
            }
            Text("本机离线自对弈；仅经完整胜负验证及去重的记录计数。")
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
            Toggle("允许原生 Bot 使用已保存的自对弈经验",
                   isOn: $engine.selfPlayLearningEnabled)
                .font(.caption)
                .tint(VeilTheme.gold)

            if engine.isNativeTraining {
                ProgressView(value: Double(engine.trainingAttempted),
                             total: Double(max(1, engine.trainingTarget)))
                HStack {
                    Text("\(engine.trainingAttempted) / \(engine.trainingTarget) · 拒收 \(engine.trainingRejected)")
                        .font(.caption.monospacedDigit())
                    Spacer()
                    Button("停止训练") { engine.stopNativeSelfPlay() }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(VeilTheme.goldBright)
                }
            } else {
                Menu {
                    Button("原生自对弈 10 局") {
                        engine.beginNativeSelfPlay(games: 10)
                    }
                    Button("原生自对弈 100 局") {
                        engine.beginNativeSelfPlay(games: 100)
                    }
                    Button("原生自对弈 1000 局（长时间前台运行）") {
                        engine.beginNativeSelfPlay(games: 1000)
                    }
                } label: {
                    Label("开始真正的 Bot 自对弈", systemImage: "play.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(VeilTheme.goldBright)
                }
                .disabled(engine.isBootstrappingSeed || engine.isInitialTrainingAuditRunning)
            }
            Button {
                engine.prepareNativeTrainingExport()
            } label: {
                Label(engine.isExportingNativeTraining
                      ? "正在复验并导出训练记录"
                      : "导出自对弈明细（逐手棋谱）",
                      systemImage: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(VeilPhysicalButtonStyle())
            .disabled(engine.isExportingNativeTraining || engine.isNativeTraining
                      || engine.isInitialTrainingAuditRunning || engine.trainedGames == 0)
            .accessibilityIdentifier("gomoku.training.export.verified")
            if let exported = engine.nativeTrainingExportURL {
                ShareLink(item: exported) {
                    Label("分享已验证的自对弈 JSON", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityIdentifier("gomoku.training.share.verified")
            }
            if let warning = engine.trainingWarning {
                Text(warning)
                    .font(.caption2)
                    .foregroundColor(VeilTheme.danger)
            }
        }
        .padding(10)
        .background(VeilTheme.subtleFillStrong,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityIdentifier("gomoku.training.native-selfplay")
    }

    private var coachSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let profile = engine.coachProfile {
                Text("个性化教练 · Lv\(profile.level) · \(profile.favoriteOpening)")
                    .font(.caption.weight(.semibold))
                Text(profile.nextLesson)
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
                Text(profile.reviewFocus)
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
            } else {
                Text("个人教练 · 等待本机数据分析")
                    .font(.caption.weight(.semibold))
            }
            Button("查看个人教练与真实学习统计") {
                showingCoach = true
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(VeilTheme.goldBright)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(VeilTheme.gold.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("棋谱与本机档案")
                .font(.subheadline.weight(.semibold))
            Text("已归档 \(engine.archivedGames) 局 · 棋谱导入只进入档案，不自动生成本机学习证据。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
            HStack(spacing: 10) {
                Button {
                    choosingMatch = true
                } label: {
                    Label("导入棋谱", systemImage: "square.and.arrow.down")
                }
                Button {
                    matchExportURL = engine.exportRecentMatch()
                } label: {
                    Label("准备导出", systemImage: "square.and.arrow.up")
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(VeilPhysicalButtonStyle())
            if let matchExportURL {
                ShareLink(item: matchExportURL) {
                    Label("分享最新棋谱", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityIdentifier("gomoku.match.share")
            }
        }
        .veilCard()
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("拟物仪器外观", systemImage: "circle.lefthalf.filled")
                .font(.subheadline.weight(.semibold))
            Picker("颜色模式", selection: $appearance.colorMode) {
                ForEach(VeilColorMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("gomoku.instrument.appearance")
            Text("仪器风格固定；仅切换浅色、深色或跟随系统。")
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
            Text("Gomoku V\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") \("RC1") · Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")")
                .font(.caption2.monospacedDigit())
                .foregroundColor(VeilTheme.secondaryText)
                .accessibilityIdentifier("gomoku.app.version")
        }
        .veilCard()
    }

    private var statusText: String {
        switch engine.status {
        case 1: return "黑方获胜"
        case 2: return "白方获胜"
        case 3: return "平局"
        default:
            if engine.developerTeachingMode { return "私有阵法教学进行中" }
            if engine.isThinking { return "ECLIPSE 正在思考" }
            return canPlaceStone ? "轮到你落子" : "等待 ECLIPSE 落子"
        }
    }
}

private struct EclipseAnalysisPresentation: View {
    @ObservedObject var engine: NativeGomokuAppController
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let active = scenePhase == .active && engine.isThinking
        TimelineView(.periodic(from: .now, by: active ? 0.5 : 30)) { _ in
            VeilEclipseTraceSheet(
                isThinking: active,
                matchFinished: engine.status != 0,
                lastCompletedMilliseconds: engine.lastDecisionMilliseconds,
                actualSearchStartedAt: active ? engine.searchStartedAt : nil,
                committedMoves: engine.completedMoves,
                difficultyTitle: engine.selectedModel.name,
                searchModeTitle: engine.searchMode.title,
                liveMetrics: engine.realSearchMetrics,
                archivedMatchPage: engine.historyPage(offset:limit:)
            )
        }
    }
}
