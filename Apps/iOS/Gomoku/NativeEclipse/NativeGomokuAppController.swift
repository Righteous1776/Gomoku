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
    @Published private(set) var lastDecisionMilliseconds: Int?
    @Published private(set) var fallbackWarning: String?
    @Published var humanIsBlack = true
    @Published var difficulty: BoardBotDifficulty = .balanced
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
    @Published private(set) var isNativeTraining = false
    @Published private(set) var isBootstrappingSeed = false
    @Published private(set) var trainingWarning: String?
    @Published private(set) var legacyImportStatus: String?
    @Published private(set) var isImportingLegacyLearning = false
    @Published private(set) var trainingAttempted = 0
    @Published private(set) var trainingTarget = 0
    @Published private(set) var trainingRejected = 0
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
    let developerAuthorization = GomokuDeveloperAuthorization()
    private let developerLessons = GomokuDeveloperLessonLibrary()
    private var generation = UUID()
    private var searchTask: Task<Void, Never>?
    private let archive: VeilGomokuMatchArchive
    private let trainingJournal: GomokuNativeTrainingJournal
    private let localMatchEvidence: GomokuLocalMatchEvidence
    private var sessionHasLocalProvenance = true
    private lazy var transfer = GomokuMatchTransfer(archive: archive)
    private(set) var sessionID = UUID().uuidString
    private var sessionHumanStone: UInt8 = 1
    private var archivedMoves: [VeilGomokuMatchArchive.Move] = []
    private var trainingTask: Task<Void, Never>?
    private var trainingGeneration = UUID()
    private let trainingWriteGate = GomokuTrainingWriteGate()

    init(archiveDirectory: URL? = nil, trainingDirectory: URL? = nil) {
        archive = VeilGomokuMatchArchive(directory: archiveDirectory)
        trainingJournal = GomokuNativeTrainingJournal(directory: trainingDirectory)
        let root = archive.directory.deletingLastPathComponent()
        localMatchEvidence = GomokuLocalMatchEvidence(
            directory: root.appendingPathComponent("VerifiedLocalLearningV1", isDirectory: true)
        )
        trainedGames = trainingJournal.count()
        archivedGames = (try? archive.page(limit: 1).totalFiles) ?? 0
        recoveryAvailable = latestRestorableMatch() != nil
        savedDeveloperLessons = developerLessons.lessons.count
        // Seed bootstrap runs only for the production sandbox; injected test
        // directories never silently receive fixture or bundled data.
        if archiveDirectory == nil && trainingDirectory == nil {
            beginSeedBootstrap()
        }
    }

    var humanColor: Int32 { humanIsBlack ? 1 : 2 }

    var completedMoves: [VeilEclipseTracePolicy.PlacedMove] {
        guard status != 0 else { return [] }
        return archivedMoves.map { .init(index: $0.index, stone: $0.stone) }
    }

    private func latestRestorableMatch() -> VeilGomokuMatchArchive.Match? {
        var offset = 0
        while let page = try? archive.page(offset: offset, limit: 50) {
            for record in page.matches where record.status == .playing {
                if Self.replayIncompleteMatch(record) != nil { return record }
            }
            guard let next = page.nextOffset, next > offset else { break }
            offset = next
        }
        return nil
    }

    private static func replayIncompleteMatch(
        _ record: VeilGomokuMatchArchive.Match
    ) -> GomokuState? {
        guard record.status == .playing, record.completedAt == nil,
              BoardBotDifficulty(rawValue: record.difficulty) != nil else { return nil }
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
              let restoredTier = BoardBotDifficulty(rawValue: previous.difficulty) else {
            recoveryAvailable = false
            return false
        }
        generation = UUID()
        searchTask?.cancel()
        searchTask = nil
        eclipseTraceStore.clear()
        state = resumed
        sessionID = previous.id
        sessionHasLocalProvenance = localMatchEvidence.isVerifiedLocal(previous)
        sessionHumanStone = previous.humanStone
        humanIsBlack = previous.humanStone == 1
        difficulty = restoredTier
        archivedMoves = previous.moves
        isThinking = false
        searchStartedAt = nil
        fallbackWarning = nil
        lastDecisionNodes = nil
        lastDecisionMilliseconds = nil
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
        searchTask?.cancel()
        searchTask = nil
        eclipseTraceStore.clear()
        state = GomokuState()
        sessionID = UUID().uuidString
        sessionHasLocalProvenance = true
        sessionHumanStone = humanIsBlack ? 1 : 2
        archivedMoves.removeAll()
        isThinking = false
        searchStartedAt = nil
        lastDecisionNodes = nil
        lastDecisionMilliseconds = nil
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
        searchTask?.cancel()
        searchTask = nil
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

    private func scheduleAI() {
        guard !isThinking, status == 0 else { return }
        let token = generation
        let boardAtStart = state
        let selectedTier = difficulty
        let selectedMode = searchMode
        isThinking = true
        searchStartedAt = Date()
        fallbackWarning = nil
        let traceStore = eclipseTraceStore
        let observer: (@Sendable ([Int], Int) -> Void)?
        if eclipseVisualizationEnabled, let traceToken = traceStore.begin(sessionID: sessionID, board: boardAtStart) {
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
            // Construct from verified records off the main/UI actor. The exact
            // immutable snapshot is used for this decision, not display only.
            let learning = GomokuLearningRepertoire.build(
                journalDirectory: journalDirectory,
                archiveDirectory: archiveDirectory,
                currentMoves: existingMoves,
                humanStone: humanStone,
                includeNativeSelfPlay: useNativeTraining
            ).snapshot.applying(lessonInfluence)
            guard !Task.isCancelled else { return }
            let budget = GomokuBotBudget.forDifficulty(
                selectedTier, profileLabel: selectedMode.budgetProfileLabel
            ).reinforced(by: learning.trainingLevel)
            let decision = GomokuBot.chooseMove(
                in: boardAtStart,
                for: boardAtStart.currentPlayer,
                budget: budget,
                learning: learning,
                formationPreference: activeFormation,
                difficultyRawValue: selectedTier.rawValue,
                onExploredLine: observer
            )
            guard !Task.isCancelled else { return }
            await self?.applyDecision(decision, boardAtStart: boardAtStart, token: token)
        }
    }

    private func applyDecision(
        _ decision: GomokuBotMove?, boardAtStart: GomokuState, token: UUID
    ) {
        // The detached worker never captures mutable actor-isolated self in a
        // concurrently executing MainActor.run closure (Swift 6 safe).
        guard token == generation, state == boardAtStart else { return }
        eclipseTraceStore.clear()
        isThinking = false
        searchStartedAt = nil
        searchTask = nil
        lastDecisionNodes = decision?.nodes
        lastDecisionMilliseconds = decision?.elapsedMilliseconds
        let selectedIndex: Int
        if let decision, boardAtStart.value(at: decision.index) == 0 {
            selectedIndex = decision.index
        } else if let legal = (0..<225).first(where: { boardAtStart.value(at: $0) == 0 }) {
            selectedIndex = legal
            fallbackWarning = "搜索未返回有效落子，已采用合法性保底；本局不计入棋力评测。"
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
                difficulty: difficulty.rawValue,
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
            archivedGames = (try? archive.page(limit: 1).totalFiles) ?? archivedGames
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
        guard developerAuthorization.isAuthorized else {
            legacyImportStatus = "只有通过设备持有人身份验证的开发者才能导入私有训练包。"
            return
        }
        guard !isImportingLegacyLearning else { return }
        isImportingLegacyLearning = true
        legacyImportStatus = nil
        let expiresAt = developerAuthorization.authorizedUntil ?? .distantPast
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let report = try GomokuLegacyLearningImporter().importPackage(
                    from: url, authorizationExpiresAt: expiresAt
                )
                await self?.finishLegacyImport(
                    message: "原版训练已验证导入 \(report.imported) 局；重复 \(report.duplicate) 局；跳过中国象棋 \(report.ignoredNonGomoku) 项。"
                )
            } catch {
                await self?.finishLegacyImport(message: error.localizedDescription)
            }
        }
    }

    private func finishLegacyImport(message: String) {
        legacyImportStatus = message
        isImportingLegacyLearning = false
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
            archivedGames = try archive.page(limit: 1).totalFiles
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
