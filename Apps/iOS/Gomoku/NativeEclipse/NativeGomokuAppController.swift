import Foundation
import Combine

/// Standalone Swift ECLIPSE driver. Uses the original VeilLink GomokuBot,
/// its exact tactical gates, native unified search and seven-level budgets.
/// Does not silently replace research C++ files or claim historical training
/// data migrated. No network, Xiangqi or VeilLink messaging dependencies.
@MainActor
final class NativeGomokuAppController: ObservableObject {
    @Published private(set) var board = [UInt8](repeating: 0, count: 225)
    @Published private(set) var toMove: Int32 = 1
    @Published private(set) var status: Int32 = 0
    @Published private(set) var isThinking = false
    @Published private(set) var searchStartedAt: Date?
    @Published private(set) var lastDecisionNodes: Int?
    @Published private(set) var lastDecisionDepth: Int?
    @Published private(set) var lastDecisionMilliseconds: Int?
    @Published private(set) var lastExecutedModel: EclipseModelID?
    @Published private(set) var lastExecutedTrainerRevision: String?
    @Published private(set) var lastExecutionBackend: String?
    @Published private(set) var fallbackWarning: String?
    // Versioned, read-only HUD identity. A model label alone is never proof
    // the corresponding C++ forest was actually loaded.
    @Published private(set) var activeThinkingRun: EclipseThinkingRunIdentity?
    @Published private(set) var lastThinkingRun: EclipseThinkingRunIdentity?
    @Published private(set) var lastThinkingStopReason: String?
    @Published private(set) var lastAdaptiveSearchEvidence: EclipseAdaptiveStopEvidence?
    private var searchStartedUptime: TimeInterval?
    // Ephemeral measured latencies only: isolated by executed SHA/policy,
    // bounded to 16 signatures x 128 samples, no private game records.
    private var nativeLatencyBySignature: [String: [Int]] = [:]
    private var nativeLatencyOrder: [String] = []
    @Published var humanIsBlack = true
    @Published private(set) var selectedModel: EclipseModelID = .currentDefault
    @Published private(set) var computeTier: EclipseComputeTier = .standard
    var currentModelSelection: EclipseModelSelection {
        EclipseModelSelection(model: selectedModel, compute: computeTier)
    }
    /// Compatibility with original Swift tests and seven-tier history.
    var difficulty: BoardBotDifficulty {
        get { currentModelSelection.legacyDifficulty }
        set {
            let restored = EclipseModelSelection.fromLegacyDifficulty(newValue)
            selectedModel = restored.model
            computeTier = restored.compute
        }
    }
    @Published var searchMode: BoardSearchMode = .full
    @Published private(set) var archivedGames = 0
    @Published private(set) var recoveryAvailable = false
    @Published private(set) var developerTeachingMode = false
    @Published private(set) var coachProfile: GomokuCoachProfile?
    @Published private(set) var isCoachLoading = false
    @Published private(set) var developerMessage: String?
    @Published private(set) var savedDeveloperLessons = 0
    @Published var formationMode: GomokuFormationMode = .automatic
    @Published private(set) var archiveWarning: String?
    @Published private(set) var trainedGames = 0
    @Published private(set) var isInitialTrainingAuditRunning = true
    @Published private(set) var isNativeTraining = false
    @Published private(set) var isBootstrappingSeed = false
    @Published private(set) var trainingWarning: String?
    @Published private(set) var legacyImportStatus: String?
    @Published private(set) var isImportingLegacyLearning = false
    @Published private(set) var trainingAttempted = 0
    @Published private(set) var trainingTarget = 0
    @Published private(set) var trainingRejected = 0
    @Published private(set) var isExportingNativeTraining = false
    @Published private(set) var nativeTrainingExportURL: URL?
    @Published var selfPlayLearningEnabled = UserDefaults.standard.object(forKey: "gomoku.eclipse.selfplay-feedback") as? Bool ?? true {
        didSet { UserDefaults.standard.set(selfPlayLearningEnabled, forKey: "gomoku.eclipse.selfplay-feedback") }
    }

    @Published var eclipseVisualizationEnabled = UserDefaults.standard.bool(forKey: "gomoku.eclipse.live-trace") {
        didSet {
            UserDefaults.standard.set(eclipseVisualizationEnabled, forKey: "gomoku.eclipse.live-trace")
            if !eclipseVisualizationEnabled { eclipseTraceStore.clear() }
        }
    }

    private(set) var state = GomokuState()
    let eclipseTraceStore = VeilEclipseSearchTraceStore()
    let eclipseMetricsStore = VeilEclipseMeasuredMetricsStore()
    let developerAuthorization = GomokuDeveloperAuthorization()
    private let developerLessons = GomokuDeveloperLessonLibrary()
    private var generation = UUID()
    private var searchTask: Task<Void, Never>?
    private var activeCppSearch: EclipseCppProductionAdapter?
    private let archive: VeilGomokuMatchArchive
    private let trainingJournal: GomokuNativeTrainingJournal
    private let verifiedTrainerExecutions:
        [EclipseModelID: EclipseVerifiedTrainerExecution]
    private var verifiedTrainerExecution: EclipseVerifiedTrainerExecution? {
        verifiedTrainerExecutions[selectedModel]
    }

    /// Each 2.0 forest is independently compiled, attested and selectable.
    /// A manifest entry alone never enables the model.
    var verifiedSelectableModels: [EclipseModelID] {
        // loadAllFromBundle has ALREADY verified each exact C++ forest during
        // app initialization. Do not create extra native engines on each
        // SwiftUI redraw; C++ make()/decide() re-attest active bytes per turn.
        [.astra20, .sol20].filter {
            verifiedTrainerExecutions[$0] != nil
        }
    }

    /// Compatibility with single-checkpoint inspection surfaces.
    var verifiedSelectableModel: EclipseModelID? {
        verifiedSelectableModels.first
    }

    var availableModels: [EclipseModelID] {
        EclipseModelID.featuredIncludingVerified(verifiedSelectableModels)
    }

    var trainerControlsCompute: Bool {
        selectedModel.requiresVerifiedCheckpoint
            && verifiedTrainerExecution != nil
            && verifiedSelectableModels.contains(selectedModel)
    }
    private let localMatchEvidence: GomokuLocalMatchEvidence
    private var sessionHasLocalProvenance = true
    private lazy var transfer = GomokuMatchTransfer(archive: archive)
    private(set) var sessionID = UUID().uuidString
    private var sessionHumanStone: UInt8 = 1
    private var archivedMoves: [VeilGomokuMatchArchive.Move] = []
    private var trainingTask: Task<Void, Never>?
    private var trainingGeneration = UUID()
    private let trainingWriteGate = GomokuTrainingWriteGate()

    init(
        archiveDirectory: URL? = nil,
        trainingDirectory: URL? = nil,
        verifiedTrainerExecution: EclipseVerifiedTrainerExecution? = nil
    ) {
        // The official application resolves its signed/verified C++ runtime
        // binding at launch, without requiring DEBUG tools or a manual
        // injection. Isolated XCTest archive roots remain deterministic.
        let productionInstall = archiveDirectory == nil && trainingDirectory == nil
        if let explicit = verifiedTrainerExecution {
            self.verifiedTrainerExecutions = [explicit.model: explicit]
        } else if productionInstall {
            self.verifiedTrainerExecutions =
                EclipseTrainerProductionRegistry.loadAllFromBundle()
        } else {
            self.verifiedTrainerExecutions = [:]
        }
        archive = VeilGomokuMatchArchive(directory: archiveDirectory)
        trainingJournal = GomokuNativeTrainingJournal(directory: trainingDirectory)
        let root = archive.directory.deletingLastPathComponent()
        localMatchEvidence = GomokuLocalMatchEvidence(
            directory: root.appendingPathComponent("VerifiedLocalLearningV1", isDirectory: true)
        )
        archivedGames = (try? archive.recordCount()) ?? 0
        recoveryAvailable = latestRestorableMatch() != nil
        savedDeveloperLessons = developerLessons.lessons.count
        let journalFolder = trainingJournal.directory
        let production = archiveDirectory == nil && trainingDirectory == nil
        if production {
            // First launch selects the actually installed trained model;
            // explicit user choices always override this default.
            if UserDefaults.standard.string(
                forKey: EclipseModelID.selectionKey
            ) == nil,
                let first = [EclipseModelID.astra20, .sol20].first(
                    where: { self.verifiedSelectableModels.contains($0) }
                ) {
                selectedModel = first
                computeTier = first.defaultComputeTier
            }
            if let stored = UserDefaults.standard.string(
                forKey: EclipseModelID.selectionKey
            ), let saved = EclipseModelSelection.fromArchiveValue(stored) {
                if !saved.model.requiresVerifiedCheckpoint
                    || verifiedSelectableModels.contains(saved.model) {
                    selectedModel = saved.model
                    computeTier = saved.compute
                } else {
                    fallbackWarning = "此前选择的 \(saved.model.name) 尚未在 C++ 中完成加载核验；当前暂用原版 Swift。"
                }
            }
            if let explicitlySelectedCompute = EclipseComputeTier(
                rawValue: UserDefaults.standard.string(
                    forKey: EclipseComputeTier.selectionKey
                ) ?? ""
            ) {
                computeTier = explicitlySelectedCompute
            }
        }
        // The full historical replay pass can be huge and must never block
        // the initial board render or interactive scrolling on MainActor.
        Task.detached(priority: .utility) { [weak self] in
            let report = GomokuNativeTrainingJournal(directory: journalFolder).inspect()
            await self?.finishInitialTrainingAudit(report, production: production)
        }
    }

    private func finishInitialTrainingAudit(
        _ report: GomokuNativeTrainingJournal.VerificationReport,
        production: Bool
    ) {
        trainedGames = report.accepted
        isInitialTrainingAuditRunning = false
        if report.invalid > 0 || report.duplicates > 0 {
            trainingWarning = "训练库复验发现损坏 \(report.invalid) 项、重复 \(report.duplicates) 项；原文件已保留。"
        }
        // No bootstrap overlap with the initial audit or a newly started batch.
        if production && !isNativeTraining { beginSeedBootstrap() }
    }

    var humanColor: Int32 { humanIsBlack ? 1 : 2 }

    /// A model change starts a new game: the archive records a stable model
    /// identity per game and the in-flight async worker is invalidated.
    /// This also prevents mixing different model strategies in one training
    /// match and avoids misattributing its result to the wrong model.
    func selectModel(_ model: EclipseModelID) {
        guard model != selectedModel else { return }
        if model.requiresVerifiedCheckpoint && !verifiedSelectableModels.contains(model) {
            fallbackWarning = "\(model.name) 尚无通过核验的实际 C++ 训练检查点，不能冒充已上线模型。"
            return
        }
        selectedModel = model
        computeTier = model.defaultComputeTier
        UserDefaults.standard.set(model.rawValue, forKey: EclipseModelID.selectionKey)
        UserDefaults.standard.set(computeTier.rawValue, forKey: EclipseComputeTier.selectionKey)
        reset()
    }

    /// Compute is independent of model generation, but changes the *actual*
    /// internal original Swift search tier and therefore starts a new game.
    func selectComputeTier(_ tier: EclipseComputeTier) {
        guard tier != computeTier else { return }
        computeTier = tier
        UserDefaults.standard.set(tier.rawValue, forKey: EclipseComputeTier.selectionKey)
        reset()
    }

    var realSearchMetrics: VeilEclipseTracePolicy.LiveMetrics? {
        if isThinking {
            if activeThinkingRun?.backend.hasPrefix("C++20 V") == true {
                guard let native = activeCppSearch?.liveSearchSnapshot() else {
                    return nil
                }
                return VeilEclipseTracePolicy.LiveMetrics(
                    completedDepth: native.completedDepth,
                    visitedNodes: native.nodes
                )
            }
            return eclipseMetricsStore.snapshot(
                sessionID: sessionID, turn: state.moveCount, isThinking: true
            )
        }
        if lastDecisionNodes != nil || lastDecisionDepth != nil {
            return VeilEclipseTracePolicy.LiveMetrics(
                completedDepth: lastDecisionDepth,
                visitedNodes: lastDecisionNodes
            )
        }
        return nil
    }

    /// No invented positions, likelihoods, PV, or progress percentage.
    /// The additive C++ live ABI samples genuine native nodes and fully
    /// completed iterations. Swift metrics remain session-gated. An idle or
    /// unverifiable native reader never inherits unrelated Swift metrics.
    func thinkingHUDSnapshot(
        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> EclipseThinkingHUDSnapshot {
        let identity = isThinking ? activeThinkingRun : lastThinkingRun
        let metrics = isThinking ? realSearchMetrics : nil
        // The adapter and its engine are owned by this actor until the run
        // resolves. The C++ snapshot function is explicitly concurrent-read
        // safe; generation/reset clears activeCppSearch before a new board.
        // An explicitly requested teaching analysis keeps its completed
        // idle native handle for review, but ONLY at the unchanged position
        // and while the device-owner authorization is still valid.
        let teachingReview = !isThinking && developerTeachingMode
            && developerAuthorization.isAuthorized
            && lastThinkingRun?.positionRevision == state.moveCount
            && lastThinkingRun?.backend.hasPrefix("C++20 V") == true
            && activeCppSearch != nil
        let nativeRun = (isThinking || teachingReview)
            && identity?.backend.hasPrefix("C++20 V") == true
        let nativeLive = nativeRun ? activeCppSearch?.liveSearchSnapshot() : nil
        let liveElapsed: Int? = searchStartedUptime.map {
            Int(max(0, uptime - $0) * 1000)
        }
        let live = isThinking && activeThinkingRun != nil
        let context: EclipseThinkingHUDSnapshot.Context =
            developerTeachingMode && developerAuthorization.isAuthorized
                ? .teaching : (status == 0 ? .formal : .postgame)
        var snapshot = EclipseThinkingHUDSnapshot(
            searchID: identity?.id,
            positionRevision: identity?.positionRevision ?? state.moveCount,
            context: context,
            isSearching: live,
            backend: identity?.backend
                ?? (lastExecutionBackend ?? "未提供"),
            executedModel: identity?.modelName
                ?? (live ? nil : lastExecutedModel?.name),
            checkpointSHA256: identity?.checkpointSHA256,
            computePolicySHA256: identity?.computePolicySHA256,
            elapsedMilliseconds: live ? liveElapsed : lastDecisionMilliseconds,
            visitedNodes: live
                ? (nativeRun ? nativeLive?.nodes : metrics?.visitedNodes)
                : lastDecisionNodes,
            completedDepth: live
                ? (nativeRun ? nativeLive?.completedDepth : metrics?.completedDepth)
                : lastDecisionDepth,
            stopReason: live ? nil : lastThinkingStopReason
        )
        snapshot.hasTeachingReview = teachingReview
        snapshot.adaptiveEvidence = live ? nil : lastAdaptiveSearchEvidence
        // The native engine may publish a best move for a FULLY completed
        // iteration. Only authenticated developer teaching may observe it.
        // Formally played matches do not store this move in the HUD.
        if (live || teachingReview) && context == .teaching && nativeRun,
           let candidate = nativeLive?.bestMoveForAuthorizedReview,
           nativeLive?.completedDepth != nil,
           state.value(at: candidate) == 0 {
            snapshot.verifiedTeachingCandidate = candidate
        }
        if (live || teachingReview) && context == .teaching && nativeRun,
           let serial = nativeLive?.searchSerial,
           let ranks = activeCppSearch?.liveRankedRootMoves(),
           ranks.serial == serial {
            // Validate all coordinates against the ACTUAL current board.
            // No duplicate or occupied position reaches the visualization.
            snapshot.nativeRootRanks = ranks.moves.filter {
                state.value(at: $0) == 0
            }
        }
        if (live || teachingReview) && context == .teaching && nativeRun,
           let serial = nativeLive?.searchSerial,
           let nativePV = activeCppSearch?.livePVPrefix(),
           nativePV.serial == serial,
           nativePV.depth == nativeLive?.completedDepth,
           nativePV.moves.first == nativeLive?.bestMoveForAuthorizedReview {
            // Replay every actual TT-sourced move with alternating player
            // identity and original freestyle win/terminal rules. Never
            // render a PV that collides, skips a turn or crosses game end.
            var replay = state
            var accepted = true
            for index in nativePV.moves {
                let actor = replay.currentPlayer
                guard (0..<225).contains(index),
                      replay.value(at: index) == 0,
                      replay.winner == nil, !replay.isDraw,
                      replay.apply(index: index, actor: actor)
                else {
                    accepted = false
                    break
                }
            }
            if accepted {
                snapshot.nativePVDepth = nativePV.depth
                snapshot.nativePVPrefix = nativePV.moves
            }
        }
        return snapshot
    }

    /// P50/P95 are only valid for >=20 completed native runs with the same
    /// verified model and trainer-authorized compute policy.
    func currentNativeLatencySummary() -> EclipseNativeLatencyStatistics.Summary? {
        guard !isThinking, let id = lastThinkingRun,
              let checkpoint = id.checkpointSHA256,
              let policy = id.computePolicySHA256,
              let execution = lastExecutionBackend else { return nil }
        // V2 and V3 can share a model/checkpoint SHA and the trainer's
        // geometric compute SHA while having DIFFERENT termination rules.
        return EclipseNativeLatencyStatistics.summarize(
            nativeLatencyBySignature[checkpoint + ":" + policy + ":" + execution] ?? []
        )
    }

    var completedMoves: [VeilEclipseTracePolicy.PlacedMove] {
        guard status != 0 else { return [] }
        return archivedMoves.map { .init(index: $0.index, stone: $0.stone) }
    }

    private func latestRestorableMatch() -> VeilGomokuMatchArchive.Match? {
        // One metadata sort for the whole boot/recovery operation, rather than
        // re-sorting 10,000+ entries for every 50-game page.
        try? archive.mostRecentMatch { record in
            record.status == .playing && Self.replayIncompleteMatch(record) != nil
        }
    }

    private static func replayIncompleteMatch(
        _ record: VeilGomokuMatchArchive.Match
    ) -> GomokuState? {
        guard record.status == .playing, record.completedAt == nil,
              EclipseModelSelection.fromArchiveValue(record.difficulty) != nil else { return nil }
        var restored = GomokuState()
        for move in record.moves {
            let expected: UInt8 = restored.currentPlayer == .host ? 1 : 2
            guard move.stone == expected,
                  restored.apply(index: move.index, actor: restored.currentPlayer) else {
                return nil
            }
        }
        guard restored.winner == nil, !restored.isDraw else { return nil }
        return restored
    }

    /// Explicit resume is safer than silently replacing a new in-memory match.
    /// It reads but never rewrites the old journal until a fresh legal move.
    @discardableResult
    func restoreLastPlayingSession() -> Bool {
        guard let previous = latestRestorableMatch(),
              let resumed = Self.replayIncompleteMatch(previous),
              let restored = EclipseModelSelection.fromArchiveValue(previous.difficulty) else {
            recoveryAvailable = false
            return false
        }
        generation = UUID()
        activeCppSearch?.cancel()
        activeCppSearch = nil
        searchTask?.cancel()
        searchTask = nil
        eclipseTraceStore.clear()
        eclipseMetricsStore.clear()
        activeThinkingRun = nil
        lastThinkingRun = nil
        lastThinkingStopReason = nil
        lastAdaptiveSearchEvidence = nil
        searchStartedUptime = nil
        state = resumed
        sessionID = previous.id
        sessionHasLocalProvenance = localMatchEvidence.isVerifiedLocal(previous)
        sessionHumanStone = previous.humanStone
        humanIsBlack = previous.humanStone == 1
        selectedModel = restored.model
        computeTier = restored.compute
        UserDefaults.standard.set(restored.model.rawValue, forKey: EclipseModelID.selectionKey)
        UserDefaults.standard.set(restored.compute.rawValue, forKey: EclipseComputeTier.selectionKey)
        archivedMoves = previous.moves
        isThinking = false
        searchStartedAt = nil
        fallbackWarning = nil
        lastDecisionNodes = nil
        lastDecisionDepth = nil
        lastDecisionMilliseconds = nil
        lastExecutedModel = nil
        lastExecutedTrainerRevision = nil
        lastExecutionBackend = nil
        recoveryAvailable = false
        refresh()
        if Int32(state.currentPlayer == .host ? 1 : 2) != humanColor {
            scheduleAI()
        }
        return true
    }

    func historyPage(offset: Int, limit: Int) -> VeilGomokuMatchArchive.Page? {
        try? archive.page(offset: offset, limit: limit)
    }

    func reset() {
        if !developerTeachingMode && status == 0, !archivedMoves.isEmpty {
            persistArchive(status: .interrupted)
        }
        generation = UUID()
        activeCppSearch?.cancel()
        activeCppSearch = nil
        searchTask?.cancel()
        searchTask = nil
        eclipseTraceStore.clear()
        eclipseMetricsStore.clear()
        activeThinkingRun = nil
        lastThinkingRun = nil
        lastThinkingStopReason = nil
        lastAdaptiveSearchEvidence = nil
        searchStartedUptime = nil
        state = GomokuState()
        sessionID = UUID().uuidString
        sessionHasLocalProvenance = true
        sessionHumanStone = humanIsBlack ? 1 : 2
        archivedMoves.removeAll()
        isThinking = false
        searchStartedAt = nil
        lastDecisionNodes = nil
        lastDecisionDepth = nil
        lastDecisionMilliseconds = nil
        lastExecutedModel = nil
        lastExecutedTrainerRevision = nil
        lastExecutionBackend = nil
        fallbackWarning = nil
        refresh()
        if !humanIsBlack && !developerTeachingMode { scheduleAI() }
    }

    func toggleSide() {
        humanIsBlack.toggle()
        reset()
    }

    func play(_ index: Int) {
        if developerTeachingMode {
            guard developerAuthorization.isAuthorized,
                  !isThinking, status == 0 else {
                developerMessage = "开发者身份验证已过期，无法继续示范。"
                return
            }
            let stone: UInt8 = state.currentPlayer == .host ? 1 : 2
            guard state.apply(index: index, actor: state.currentPlayer) else { return }
            archivedMoves.append(.init(index: index, stone: stone))
            // All native ranked/PV evidence belongs to the PREVIOUS board.
            activeCppSearch = nil
            lastThinkingRun = nil
            lastThinkingStopReason = nil
            lastAdaptiveSearchEvidence = nil
            lastDecisionNodes = nil
            lastDecisionDepth = nil
            lastDecisionMilliseconds = nil
            lastExecutedModel = nil
            lastExecutionBackend = nil
            refresh()
            return
        }
        guard !isThinking, status == 0, Int32(state.currentPlayer == .host ? 1 : 2) == humanColor,
              state.apply(index: index, actor: state.currentPlayer) else { return }
        archivedMoves.append(.init(index: index, stone: UInt8(humanColor)))
        persistArchive(status: archiveStatus())
        refresh()
        if status == 0 { scheduleAI() }
    }

    private func refresh() {
        board = (0..<225).map { UInt8(max(0, state.value(at: $0))) }
        toMove = state.currentPlayer == .host ? 1 : 2
        if state.winner == .host { status = 1 }
        else if state.winner == .guest { status = 2 }
        else if state.isDraw { status = 3 }
        else { status = 0 }
    }

    func refreshCoachProfile() {
        guard !isCoachLoading else { return }
        isCoachLoading = true
        let archiveDirectory = archive.directory
        let trainingDirectory = trainingJournal.directory
        let lessons = developerLessons.lessons.count
        Task.detached(priority: .utility) { [weak self] in
            let profile = GomokuCoachProfile.build(
                archiveDirectory: archiveDirectory,
                trainingDirectory: trainingDirectory,
                developerFormationCount: lessons
            )
            await self?.finishCoachProfile(profile)
        }
    }

    private func finishCoachProfile(_ profile: GomokuCoachProfile) {
        coachProfile = profile
        isCoachLoading = false
    }

    var developerLessonList: [GomokuDeveloperLessonLibrary.Lesson] {
        developerLessons.lessons
    }

    func beginDeveloperTeaching() {
        guard developerAuthorization.isAuthorized, !isNativeTraining,
              !isBootstrappingSeed else {
            developerMessage = "请先通过设备身份验证，并等待其他训练结束。"
            return
        }
        developerTeachingMode = true
        reset() // Teaching moves are never persisted into ordinary match history.
        developerMessage = nil
    }

    func stopDeveloperTeaching() {
        developerTeachingMode = false
        generation = UUID()
        activeCppSearch?.cancel()
        activeCppSearch = nil
        searchTask?.cancel()
        searchTask = nil
        eclipseTraceStore.clear()
        eclipseMetricsStore.clear()
        activeThinkingRun = nil
        lastThinkingRun = nil
        lastThinkingStopReason = nil
        lastAdaptiveSearchEvidence = nil
        searchStartedUptime = nil
        state = GomokuState()
        archivedMoves.removeAll()
        sessionID = UUID().uuidString
        sessionHasLocalProvenance = true
        isThinking = false
        searchStartedAt = nil
        refresh()
        developerMessage = nil
    }

    func saveDeveloperLesson(name: String, purpose: String, objective: String) {
        guard developerTeachingMode, developerAuthorization.isAuthorized else {
            developerMessage = "授权失效，不能保存教学内容。"
            return
        }
        do {
            try developerLessons.capture(
                name: name, purpose: purpose, objective: objective,
                moves: archivedMoves.map { .init(index: $0.index, stone: $0.stone) },
                authorized: developerAuthorization.isAuthorized
            )
            savedDeveloperLessons = developerLessons.lessons.count
            developerMessage = "阵法已验证并签名保存，可在相同棋谱前缀加入正式搜索偏好。"
        } catch {
            developerMessage = error.localizedDescription
        }
    }

    func removeDeveloperLesson(id: UUID) {
        do {
            try developerLessons.remove(id: id, authorized: developerAuthorization.isAuthorized)
            savedDeveloperLessons = developerLessons.lessons.count
            developerMessage = "阵法已删除。"
        } catch {
            developerMessage = error.localizedDescription
        }
    }

    /// Run native ECLIPSE at the current manually staged teaching position.
    /// IMPORTANT: this does NOT place a stone, archive a match, train a model
    /// or alter the original automatic gameplay path. A compiled, attested
    /// 2.0 Astra/Sol backend is required for live ranked/PV evidence.
    func analyzeTeachingPosition() {
        guard developerTeachingMode, developerAuthorization.isAuthorized,
              !isThinking, !isNativeTraining, !isBootstrappingSeed,
              status == 0 else { return }
        guard let trainer = verifiedTrainerExecution,
              let runtime = EclipseCppProductionAdapter.make(
                history: archivedMoves.map(\.index), trainer: trainer
              ) else {
            developerMessage = "当前模型没有完成 C++ 原生加载核验，不能产生真实候选/PV。"
            return
        }
        let boardAtStart = state
        let token = generation
        let model = selectedModel
        // Release previously reviewed engine before beginning a fresh run.
        activeCppSearch = runtime
        lastThinkingRun = nil
        lastThinkingStopReason = nil
        lastAdaptiveSearchEvidence = nil
        lastDecisionNodes = nil
        lastDecisionDepth = nil
        lastDecisionMilliseconds = nil
        lastExecutedModel = nil
        lastExecutionBackend = nil
        isThinking = true
        searchStartedAt = Date()
        searchStartedUptime = ProcessInfo.processInfo.systemUptime
        activeThinkingRun = EclipseThinkingRunIdentity(
            id: UUID(), positionRevision: boardAtStart.moveCount,
            backend: trainer.computePolicy.mode == .adaptive
                && trainer.computePolicy.maxDepth >= 2
                ? "C++20 V3 adaptive" : "C++20 V2",
            modelName: model.name,
            checkpointSHA256: trainer.checkpointSHA256,
            computePolicySHA256: trainer.computePolicy.sha256
        )
        developerMessage = nil

        let moves = archivedMoves
        let journalDirectory = trainingJournal.directory
        let archiveDirectory = archive.directory
        let useNativeTraining = selfPlayLearningEnabled
        // The teaching analysis player is whichever color is to move.
        let toMoveStone: UInt8 = boardAtStart.currentPlayer == .host ? 1 : 2
        let otherStone: UInt8 = toMoveStone == 1 ? 2 : 1
        let lessonInfluence = developerLessons.influence(
            for: moves.map { .init(index: $0.index, stone: $0.stone) },
            aiStone: toMoveStone
        )
        let aiMoves = moves.filter { $0.stone == toMoveStone }.map(\.index)
        let opponentMoves = moves.filter { $0.stone == otherStone }.map(\.index)
        let formation = GomokuFormationPreference(
            mode: formationMode, aiHistory: aiMoves,
            opponentHistory: opponentMoves, discovered: []
        )
        searchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            let learned = GomokuLearningRepertoire.build(
                journalDirectory: journalDirectory,
                archiveDirectory: archiveDirectory,
                currentMoves: moves,
                humanStone: otherStone,
                includeNativeSelfPlay: useNativeTraining
            ).snapshot.applying(lessonInfluence)
            guard !Task.isCancelled else { return }
            let rooted = EclipseCppRootLearningPolicy.build(
                state: boardAtStart,
                player: boardAtStart.currentPlayer,
                learning: learned,
                formation: formation
            )
            let result = runtime.decide(
                policy: trainer.computePolicy, rootPolicy: rooted
            )
            guard !Task.isCancelled else { return }
            await self?.finishTeachingAnalysis(
                result, on: boardAtStart, token: token,
                model: model, runtime: runtime
            )
        }
    }

    private func finishTeachingAnalysis(
        _ decision: GomokuBotMove?,
        on original: GomokuState,
        token: UUID,
        model: EclipseModelID,
        runtime: EclipseCppProductionAdapter
    ) {
        guard token == generation, state == original,
              activeCppSearch === runtime else { return }
        // Authorization can expire during a long native search. It must
        // terminate the HUD without retaining a candidate or PV.
        guard developerTeachingMode, developerAuthorization.isAuthorized else {
            activeCppSearch = nil
            activeThinkingRun = nil
            lastThinkingRun = nil
            isThinking = false
            searchStartedAt = nil
            searchStartedUptime = nil
            searchTask = nil
            developerMessage = "开发者验证已过期；本次分析证据已丢弃。"
            return
        }
        lastThinkingRun = activeThinkingRun
        activeThinkingRun = nil
        searchStartedUptime = nil
        searchStartedAt = nil
        isThinking = false
        searchTask = nil
        guard let decision,
              (0..<225).contains(decision.index),
              original.value(at: decision.index) == 0,
              decision.nativeStopReason != nil else {
            activeCppSearch = nil
            lastThinkingRun = nil
            lastThinkingStopReason = "原生教学分析未获得合法结果"
            developerMessage = "本局原生分析失败，未落子、未写入训练或对局记录。"
            return
        }
        // Keep this completed, idle native handle only for read-only review.
        // A manually staged move or reset immediately drops its evidence.
        lastAdaptiveSearchEvidence = decision.adaptiveEvidence
        lastDecisionNodes = decision.nodes
        lastDecisionDepth = decision.completedDepth
        lastDecisionMilliseconds = decision.elapsedMilliseconds
        lastExecutedModel = model
        lastExecutedTrainerRevision = nil
        lastExecutionBackend = decision.engineLabel ?? "C++20 V2"
        lastThinkingStopReason =
            EclipseThinkingHUDSnapshot.nativeStopReason(decision.nativeStopReason)
        developerMessage = "原生搜索完成；当前棋盘未变化，候选与 PV 仅供教学研判。"
    }

    private func scheduleAI() {
        guard !isThinking, status == 0 else { return }
        let token = generation
        let boardAtStart = state
        let model = selectedModel
        let selectedTier = currentModelSelection.legacyDifficulty
        let selectedMode = searchMode
        let verifiedTrainer = verifiedTrainerExecution?.model == model
            ? verifiedTrainerExecution : nil
        // C++20 is a real RELEASE-compiled execution backend, not a DEBUG
        // research-only view. It becomes the authoritative search route
        // when the trained C++ scorer actually reports the verified digest.
        // Until that exact artifact is installed, retain original Swift
        // with a visible, non-success fallback warning.
        let cppRuntime = verifiedTrainer.flatMap {
            EclipseCppProductionAdapter.make(
                history: archivedMoves.map(\.index), trainer: $0
            )
        }
        activeCppSearch = cppRuntime
        if verifiedTrainer != nil && cppRuntime == nil {
            fallbackWarning = "训练模型尚未在 C++ 引擎中完成加载核验，当前由原版 Swift 运行。"
        }
        isThinking = true
        searchStartedAt = Date()
        searchStartedUptime = ProcessInfo.processInfo.systemUptime
        lastThinkingRun = nil
        lastThinkingStopReason = nil
        lastAdaptiveSearchEvidence = nil
        // The native runtime has been freshly created and attested at this
        // exact position. If that failed, do NOT claim selected Astra/Sol.
        let usingCpp = cppRuntime != nil && verifiedTrainer != nil
        activeThinkingRun = EclipseThinkingRunIdentity(
            id: UUID(),
            positionRevision: boardAtStart.moveCount,
            backend: usingCpp
                ? (verifiedTrainer?.computePolicy.mode == .adaptive
                   && (verifiedTrainer?.computePolicy.maxDepth ?? 0) >= 2
                    ? "C++20 V3 adaptive" : "C++20 V2") :
                (model.requiresVerifiedCheckpoint ? "Swift fallback" : "Swift"),
            modelName: usingCpp || !model.requiresVerifiedCheckpoint
                ? model.name : nil,
            checkpointSHA256: usingCpp ? verifiedTrainer?.checkpointSHA256 : nil,
            computePolicySHA256: usingCpp
                ? verifiedTrainer?.computePolicy.sha256 : nil
        )
        if verifiedTrainer == nil || cppRuntime != nil {
            fallbackWarning = nil
        }
        let traceStore = eclipseTraceStore
        let metricSink = eclipseMetricsStore
        let metricToken = metricSink.begin(
            sessionID: sessionID, turn: boardAtStart.moveCount
        )
        let metricObserver: @Sendable (VeilGomokuUnifiedSearch.Trace) -> Void = { trace in
            _ = metricSink.record(trace, token: metricToken)
        }
        let observer: (@Sendable ([Int], Int) -> Void)?
        if eclipseVisualizationEnabled && developerTeachingMode,
           let traceToken = traceStore.begin(sessionID: sessionID, board: boardAtStart) {
            observer = { indices, nodes in
                _ = traceStore.record(indices, nodes: nodes, token: traceToken)
            }
        } else {
            observer = nil
        }
        let journalDirectory = trainingJournal.directory
        let archiveDirectory = archive.directory
        let existingMoves = archivedMoves
        let humanStone = sessionHumanStone
        let useNativeTraining = selfPlayLearningEnabled
        let aiStone: UInt8 = humanStone == 1 ? 2 : 1
        let lessonInfluence = developerLessons.influence(
            for: existingMoves.map { .init(index: $0.index, stone: $0.stone) },
            aiStone: aiStone
        )
        let aiMoves = existingMoves.filter { $0.stone == aiStone }.map(\.index)
        let opponentMoves = existingMoves.filter { $0.stone == humanStone }.map(\.index)
        let activeFormation = GomokuFormationPreference(
            mode: formationMode, aiHistory: aiMoves,
            opponentHistory: opponentMoves, discovered: []
        )
        searchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            // Preserve the original ECLIPSE local learning and owner-defined
            // formation on BOTH Swift and C++ routes. Only verified local
            // evidence influences the C++ root bonuses; no private training
            // history is copied into the model or emitted over the ABI.
            let learning = GomokuLearningRepertoire.build(
                journalDirectory: journalDirectory,
                archiveDirectory: archiveDirectory,
                currentMoves: existingMoves,
                humanStone: humanStone,
                includeNativeSelfPlay: useNativeTraining
            ).snapshot.applying(lessonInfluence)
            guard !Task.isCancelled else { return }
            // The official architecture first dispatches a verified trained
            // model through native C++ V2. This is the same production worker
            // path as original Swift, not a separate developer-only game.
            if let cppRuntime, let verifiedTrainer {
                let rooted = EclipseCppRootLearningPolicy.build(
                    state: boardAtStart,
                    player: boardAtStart.currentPlayer,
                    learning: learning,
                    formation: activeFormation
                )
                let cppDecision = cppRuntime.decide(
                    policy: verifiedTrainer.computePolicy,
                    rootPolicy: rooted
                )
                guard !Task.isCancelled else { return }
                if let cppDecision {
                    await self?.applyDecision(
                        cppDecision, boardAtStart: boardAtStart, token: token,
                        executedModel: model,
                        trainerRevision: verifiedTrainer.trainingRevision
                    )
                    return
                }
                // Invalid/cancelled native search never becomes a fake model
                // success. Continue through the trusted original Swift route
                // only if the user has not cancelled the session.
            }
            // The SAME already-validated local snapshot feeds the original
            // Swift fallback, preserving exact provenance and game semantics.
            // A verified training Agent checkpoint owns its real compute
            // policy. Never pass it through legacy tier multipliers, hidden
            // time limits or local reinforcement caps.
            let budget = GomokuBotBudget.forDifficulty(
                    selectedTier, profileLabel: selectedMode.budgetProfileLabel
                ).reinforced(by: learning.trainingLevel)
            let decision = GomokuBot.chooseMove(
                in: boardAtStart,
                for: boardAtStart.currentPlayer,
                budget: budget,
                learning: learning,
                formationPreference: activeFormation,
                diagnosticEclipseUnified: model.usesTrainedUnifiedSearch,
                difficultyRawValue: model.usesTrainedUnifiedSearch
                    ? selectedTier.rawValue : nil,
                trainerSearchLimits: nil,
                onExploredLine: observer,
                onSearchTrace: metricObserver
            )
            guard !Task.isCancelled else { return }
            await self?.applyDecision(
                decision, boardAtStart: boardAtStart, token: token,
                executedModel: model,
                trainerRevision: nil,
                cppFailed: cppRuntime != nil
            )
        }
    }

    private func applyDecision(
        _ decision: GomokuBotMove?, boardAtStart: GomokuState, token: UUID,
        executedModel: EclipseModelID,
        trainerRevision: String?,
        cppFailed: Bool = false
    ) {
        // The detached worker never captures mutable actor-isolated self in a
        // concurrently executing MainActor.run closure (Swift 6 safe).
        guard token == generation, state == boardAtStart else { return }
        lastDecisionDepth = decision?.completedDepth
            ?? eclipseMetricsStore.snapshot(
                sessionID: sessionID, turn: boardAtStart.moveCount, isThinking: true
            )?.completedDepth
        eclipseTraceStore.clear()
        eclipseMetricsStore.clear()
        // Preserve the ID and exact revision of the completed search only.
        // Subsequent reset/model switch clears this last-run context.
        lastThinkingRun = activeThinkingRun
        activeThinkingRun = nil
        searchStartedUptime = nil
        isThinking = false
        searchStartedAt = nil
        searchTask = nil
        activeCppSearch = nil
        lastThinkingStopReason = cppFailed
            ? "C++ 搜索未返回有效结果，Swift 接管"
            : EclipseThinkingHUDSnapshot.nativeStopReason(
                trainerRevision != nil ? decision?.nativeStopReason : nil
            )
        lastAdaptiveSearchEvidence = cppFailed ? nil : decision?.adaptiveEvidence
        lastDecisionNodes = decision?.nodes
        lastDecisionMilliseconds = decision?.elapsedMilliseconds
        lastExecutedModel = nil
        lastExecutedTrainerRevision = nil
        lastExecutionBackend = nil
        if cppFailed {
            fallbackWarning = "C++ 搜索未返回有效结果，本手由原版 Swift 接管；本手不计入 C++ 棋力评测。"
        }
        let selectedIndex: Int
        if let decision, (0..<225).contains(decision.index),
           boardAtStart.value(at: decision.index) == 0 {
            selectedIndex = decision.index
            // Never claim "2.0 Astra/Sol" actually played when a missing or
            // failed native C++ V9 scorer forced the original Swift fallback.
            let verifiedV9Played = !executedModel.requiresVerifiedCheckpoint
                || trainerRevision != nil
            lastExecutedModel = verifiedV9Played ? executedModel : nil
            lastExecutedTrainerRevision = trainerRevision
            lastExecutionBackend = decision.engineLabel ?? "ECLIPSE Swift"
            if let previous = lastThinkingRun {
                lastThinkingRun = EclipseThinkingRunIdentity(
                    id: previous.id, positionRevision: previous.positionRevision,
                    backend: lastExecutionBackend ?? "未提供",
                    modelName: lastExecutedModel?.name,
                    checkpointSHA256: verifiedV9Played
                        && executedModel.requiresVerifiedCheckpoint
                        ? previous.checkpointSHA256 : nil,
                    computePolicySHA256: verifiedV9Played
                        && executedModel.requiresVerifiedCheckpoint
                        ? previous.computePolicySHA256 : nil
                )
            }
            if !verifiedV9Played {
                fallbackWarning = "本手实际由原版 Swift 接管，尚未执行验证的 2.0 训练模型；不能计入 Astra/Sol 棋力。"
            }
            if !cppFailed, trainerRevision != nil,
               decision.nativeStopReason != nil,
               decision.elapsedMilliseconds > 0,
               let verified = lastThinkingRun,
               let checkpoint = verified.checkpointSHA256,
               let policy = verified.computePolicySHA256 {
                let signature = checkpoint + ":" + policy + ":" +
                    (decision.engineLabel ?? "C++20 unknown")
                if nativeLatencyBySignature[signature] == nil {
                    nativeLatencyOrder.append(signature)
                    if nativeLatencyOrder.count > 16 {
                        nativeLatencyBySignature.removeValue(
                            forKey: nativeLatencyOrder.removeFirst()
                        )
                    }
                }
                var samples = nativeLatencyBySignature[signature] ?? []
                samples.append(decision.elapsedMilliseconds)
                if samples.count > 128 { samples.removeFirst(samples.count - 128) }
                nativeLatencyBySignature[signature] = samples
            }
        } else if let legal = (0..<225).first(where: { boardAtStart.value(at: $0) == 0 }) {
            selectedIndex = legal
            fallbackWarning = "搜索未返回有效落子，已采用合法性保底；本局不计入棋力评测。"
            lastThinkingStopReason = "搜索失败：使用合法性保底"
            lastThinkingRun = nil
        } else {
            refresh()
            return
        }
        guard state.apply(index: selectedIndex, actor: state.currentPlayer) else {
            fallbackWarning = "搜索结果未能落子，请重开棋局。"
            return
        }
        archivedMoves.append(.init(
            index: selectedIndex,
            stone: UInt8(boardAtStart.currentPlayer == .host ? 1 : 2)
        ))
        persistArchive(status: archiveStatus())
        refresh()
    }

    private func archiveStatus() -> VeilGomokuMatchArchive.Status {
        if status == 3 || state.isDraw { return .draw }
        if let winner = state.winner {
            let winnerStone: UInt8 = winner == .host ? 1 : 2
            return winnerStone == sessionHumanStone ? .humanWon : .aiWon
        }
        return .playing
    }

    private func persistArchive(status state: VeilGomokuMatchArchive.Status) {
        guard !archivedMoves.isEmpty else { return }
        do {
            let committed = try archive.save(
                sessionID: sessionID, moves: archivedMoves,
                difficulty: currentModelSelection.archiveValue,
                humanStone: sessionHumanStone, status: state
            )
            // Only actual play may create the device-keyed evidence receipt.
            // Resuming an imported reference match cannot promote it to
            // trusted learning data by adding one further local move.
            if sessionHasLocalProvenance, let committed,
               committed.status != .interrupted {
                do {
                    try localMatchEvidence.attestCommittedLocalMatch(committed)
                } catch {
                    sessionHasLocalProvenance = false
                    archiveWarning = "本机棋局已保存，但训练来源证明失败，暂不纳入 ECLIPSE 学习。"
                }
            }
            // Session ids are fresh at new-game start. A newly committed
            // first move adds exactly one file; all later moves update it.
            // Never sort the entire game history for an ordinary stone tap.
            if archivedMoves.count == 1 { archivedGames += 1 }
            if sessionHasLocalProvenance { archiveWarning = nil }
        } catch {
            archiveWarning = error.localizedDescription
        }
    }

    private func beginSeedBootstrap() {
        let flag = "gomoku.eclipse.bundled-native-seed-v1-verified"
        guard !UserDefaults.standard.bool(forKey: flag),
              let url = Bundle.main.url(
                forResource: GomokuBundledNativeSeed.resourceName, withExtension: "json"
              ) else { return }
        isBootstrappingSeed = true
        let directory = trainingJournal.directory
        Task.detached(priority: .utility) { [weak self] in
            do {
                let result = try GomokuBundledSeedBootstrap.importVerifiedSeed(
                    from: url, into: GomokuNativeTrainingJournal(directory: directory)
                )
                let complete = !Task.isCancelled && result.rejected == 0
                await self?.finishSeedBootstrap(result: result, complete: complete, flag: flag)
            } catch {
                await self?.finishSeedBootstrapFailure(error.localizedDescription)
            }
        }
    }

    private func finishSeedBootstrap(
        result: GomokuBundledSeedBootstrap.Result, complete: Bool, flag: String
    ) {
        trainedGames = result.totalValid
        isBootstrappingSeed = false
        if complete {
            UserDefaults.standard.set(true, forKey: flag)
        } else {
            trainingWarning = "首次训练种子未完整导入，已保留有效棋谱；下次启动可重试。"
        }
    }

    private func finishSeedBootstrapFailure(_ message: String) {
        isBootstrappingSeed = false
        trainingWarning = "内置训练种子校验或导入失败：" + message
    }

    func beginNativeSelfPlay(games: Int = 10) {
        guard !isNativeTraining, !isBootstrappingSeed,
              !isInitialTrainingAuditRunning,
              [1, 10, 100, 1000].contains(games) else { return }
        trainingGeneration = UUID()
        let token = trainingGeneration
        trainingWriteGate.begin(token)
        isNativeTraining = true
        trainingWarning = nil
        trainingAttempted = 0
        trainingRejected = 0
        trainingTarget = games
        let directory = trainingJournal.directory
        let gate = trainingWriteGate

        trainingTask = Task.detached(priority: .utility) { [weak self] in
            // The full archive audit and all disk writes run on the worker,
            // never on MainActor or in the board's gesture event loop.
            let writer: GomokuNativeTrainingJournal.BatchWriter
            do {
                writer = try GomokuNativeTrainingJournal(
                    directory: directory
                ).makeBatchWriter()
            } catch {
                await self?.failNativeTrainingBatch(error.localizedDescription, token: token)
                return
            }
            for batch in 0..<games {
                guard !Task.isCancelled, gate.isCurrent(token) else { break }
                let seed = writer.initialValidCount + batch
                let played = NativeGomokuSelfPlay.play(
                    seed: seed, formationMode: .off
                )
                guard !Task.isCancelled, gate.isCurrent(token) else { break }
                guard let played else {
                    await self?.recordNativeTrainingAttempt(
                        validCount: nil, message: "本局未形成合法终局，已拒收。",
                        token: token
                    )
                    continue
                }
                do {
                    let count = try gate.commit(generation: token) {
                        try writer.append(played, seed: seed)
                        return writer.totalValidCount
                    }
                    guard let count else { break }
                    await self?.recordNativeTrainingAttempt(
                        validCount: count, message: nil, token: token
                    )
                } catch {
                    await self?.recordNativeTrainingAttempt(
                        validCount: nil, message: error.localizedDescription,
                        token: token
                    )
                }
            }
            await self?.finishNativeTrainingSession(token)
        }
    }

    private func recordNativeTrainingAttempt(
        validCount: Int?, message: String?, token: UUID
    ) {
        guard isNativeTraining && trainingGeneration == token else { return }
        trainingAttempted += 1
        if let validCount {
            trainedGames = validCount
        } else {
            trainingRejected += 1
            trainingWarning = message
        }
    }

    private func failNativeTrainingBatch(_ message: String, token: UUID) {
        guard trainingGeneration == token else { return }
        trainingWarning = "训练数据库复验失败，原始资料已保留：" + message
        finishNativeTrainingSession(token)
    }

    private func finishNativeTrainingSession(_ token: UUID) {
        guard isNativeTraining && trainingGeneration == token else { return }
        trainingWriteGate.revoke()
        isNativeTraining = false
        trainingTask = nil
    }

    func importLegacyLearning(from url: URL) {
        guard let permit = developerAuthorization.importPermit else {
            legacyImportStatus = "只有通过设备持有人身份验证的开发者才能导入私有训练包。"
            return
        }
        guard !isImportingLegacyLearning else { return }
        isImportingLegacyLearning = true
        legacyImportStatus = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let report = try GomokuLegacyLearningImporter().importPackage(
                    from: url, authorization: permit
                )
                await self?.finishLegacyImport(
                    message: "原版训练导入 \(report.imported) 局，重复 \(report.duplicate) 局；完整保留 \(report.preservedPartialGames) 局未完成棋谱、\(report.preservedHashedPositions) 条局面统计；隔离 \(report.quarantinedFragments) 条原版截断记录；排除象棋 \(report.ignoredNonGomoku) 项。",
                    updatedLearning: report.imported > 0
                )
            } catch {
                await self?.finishLegacyImport(
                    message: error.localizedDescription, updatedLearning: false
                )
            }
        }
    }

    private func finishLegacyImport(message: String, updatedLearning: Bool) {
        legacyImportStatus = message
        isImportingLegacyLearning = false
        if updatedLearning { refreshCoachProfile() }
    }

    /// Matching the original VeilLink self-play details affordance, without
    /// confusing its verified native journal with legacy .vltrain packages.
    /// Full replay validation and JSON streaming run outside MainActor.
    func prepareNativeTrainingExport() {
        guard !isExportingNativeTraining else { return }
        isExportingNativeTraining = true
        let journalDirectory = trainingJournal.directory
        Task.detached(priority: .utility) { [weak self] in
            do {
                let url = try GomokuNativeTrainingJournal(
                    directory: journalDirectory
                ).exportVerifiedDetails()
                await self?.completeNativeTrainingExport(url: url, error: nil)
            } catch {
                await self?.completeNativeTrainingExport(
                    url: nil, error: error.localizedDescription
                )
            }
        }
    }

    private func completeNativeTrainingExport(url: URL?, error: String?) {
        if let previous = nativeTrainingExportURL, previous != url {
            try? FileManager.default.removeItem(at: previous)
        }
        nativeTrainingExportURL = url
        isExportingNativeTraining = false
        if let error { trainingWarning = error }
    }

    func exportRecentMatch() -> URL? {
        do {
            archiveWarning = nil
            return try transfer.exportMostRecent()
        } catch {
            archiveWarning = error.localizedDescription
            return nil
        }
    }

    func importMatch(from url: URL) {
        do {
            _ = try transfer.importMatch(from: url)
            archivedGames = try archive.recordCount()
            archiveWarning = nil
        } catch {
            archiveWarning = error.localizedDescription
        }
    }

    func stopNativeSelfPlay() {
        // Invalidate the file-write gate BEFORE accepting a new generation.
        // A stale detached worker cannot append after this method returns.
        trainingWriteGate.revoke()
        trainingGeneration = UUID()
        trainingTask?.cancel()
        trainingTask = nil
        isNativeTraining = false
    }
}
